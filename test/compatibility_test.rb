# -*- encoding: utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

# Test to ensure that existing representations in database do not break on
# migrating to new versions of this gem. This ensures that future versions of
# this gem will retain backwards compatibility with data generated by earlier
# versions.
class CompatibilityTest < Test::Unit::TestCase
  def self.setup
    ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => ':memory:'
    ActiveRecord::Base.connection.tables.each { |table| ActiveRecord::Base.connection.drop_table(table) }
    create_tables
  end

  def self.create_tables
    silence_stream(STDOUT) do
      ActiveRecord::Schema.define(:version => 1) do
        create_table :nonmarshalling_pets do |t|
          t.string :name
          t.string :encrypted_nickname
          t.string :encrypted_nickname_iv
          t.string :encrypted_nickname_salt
          t.string :encrypted_birthdate
          t.string :encrypted_birthdate_iv
          t.string :encrypted_birthdate_salt
        end
        create_table :marshalling_pets do |t|
          t.string :name
          t.string :encrypted_nickname
          t.string :encrypted_nickname_iv
          t.string :encrypted_nickname_salt
          t.string :encrypted_birthdate
          t.string :encrypted_birthdate_iv
          t.string :encrypted_birthdate_salt
        end
      end
    end
  end

  setup

  class NonmarshallingPet < ActiveRecord::Base
    PET_NICKNAME_SALT = Digest::SHA256.hexdigest('my-really-really-secret-pet-nickname-salt')
    PET_NICKNAME_KEY = 'my-really-really-secret-pet-nickname-key'
    PET_BIRTHDATE_SALT = Digest::SHA256.hexdigest('my-really-really-secret-pet-birthdate-salt')
    PET_BIRTHDATE_KEY = 'my-really-really-secret-pet-birthdate-key'

    self.attr_encrypted_options[:mode] = :per_attribute_iv_and_salt

    attr_encrypted :nickname,
      :key => proc { Encryptor.encrypt(:value => PET_NICKNAME_SALT, :key => PET_NICKNAME_KEY) }
    attr_encrypted :birthdate,
      :key => proc { Encryptor.encrypt(:value => PET_BIRTHDATE_SALT, :key => PET_BIRTHDATE_KEY) }
  end

  class MarshallingPet < ActiveRecord::Base
    PET_NICKNAME_SALT = Digest::SHA256.hexdigest('my-really-really-secret-pet-nickname-salt')
    PET_NICKNAME_KEY = 'my-really-really-secret-pet-nickname-key'
    PET_BIRTHDATE_SALT = Digest::SHA256.hexdigest('my-really-really-secret-pet-birthdate-salt')
    PET_BIRTHDATE_KEY = 'my-really-really-secret-pet-birthdate-key'

    self.attr_encrypted_options[:mode] = :per_attribute_iv_and_salt

    attr_encrypted :nickname,
      :key => proc { Encryptor.encrypt(:value => PET_NICKNAME_SALT, :key => PET_NICKNAME_KEY) },
      :marshal => true
    attr_encrypted :birthdate,
      :key => proc { Encryptor.encrypt(:value => PET_BIRTHDATE_SALT, :key => PET_BIRTHDATE_KEY) },
      :marshal => true
  end


  def test_nonmarshalling_backwards_compatibility
    self.class.setup
    pet = NonmarshallingPet.create!(
      :name => 'Fido',
      :encrypted_nickname => 'E4lJTxFG/EfkfPg5MpnriQ==',
      :encrypted_nickname_iv => 'z4Q8deE4h7f6S8NNZcbPNg==',
      :encrypted_nickname_salt => 'adcd833001a873db',
      :encrypted_birthdate => '6uKEAiFVdJw+N5El+U6Gow==',
      :encrypted_birthdate_iv => 'zxtc1XPssL4s2HwA69nORQ==',
      :encrypted_birthdate_salt => '4f879270045eaad7'
    )

    assert_equal 'Fido', pet.name
    assert_equal 'Fido the Dog', pet.nickname
    assert_equal '2011-07-09', pet.birthdate
  end

  def test_marshalling_backwards_compatibility
    self.class.setup
    # Marshalling formats changed significantly from Ruby 1.8.7 to 1.9.3.
    # Also, Date class did not correctly support marshalling pre-1.9.3, so here
    # we just marshal it as a string in the Ruby 1.8.7 case.
    if RUBY_VERSION < '1.9.3'
      pet = MarshallingPet.create!(
        :name => 'Fido',
        :encrypted_nickname => 'NhpLBIp3aKRzNZrUgUfVuceYi4x+8lE3wUsVCSI9BcU=',
        :encrypted_nickname_iv => 'wpQqrj3KN16fN6PsAerUTA==',
        :encrypted_nickname_salt => '8f1a62d274ca8a3a',
        :encrypted_birthdate => '4nbCEzcj6CjLd3B9liKm9Q==',
        :encrypted_birthdate_iv => 'Vt10PQZMrbamh/gmjSLdkQ==',
        :encrypted_birthdate_salt => 'cfb245a3df76404f'
      )
    else
      pet = MarshallingPet.create!(
        :name => 'Fido',
        :encrypted_nickname => 'EsQScJYkPw80vVGvKWkE37Px99HHpXPFjoEPTNa4rbs=',
        :encrypted_nickname_iv => 'fNq1OZcGvty4KfcvGTcFSw==',
        :encrypted_nickname_salt => '733b459b7d34c217',
        :encrypted_birthdate => '+VUlKQGfNWkOgCwI4hv+3qlGIwh9h6cJ/ranJlaxvU+xxQdL3H3cOzTcI2rkYkdR',
        :encrypted_birthdate_iv => 'Ka+zF/SwEYZKwVa24lvFfA==',
        :encrypted_birthdate_salt => 'd5e892d5bbd81566'
      )
    end

    assert_equal 'Fido', pet.name
    assert_equal 'Mummy\'s little helper', pet.nickname

    # See earlier comment.
    if RUBY_VERSION < '1.9.3'
      assert_equal '2011-07-09', pet.birthdate
    else
      assert_equal Date.new(2011, 7, 9), pet.birthdate
    end
  end
end

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => ':memory:'
