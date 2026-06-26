# frozen_string_literal: true

class CreateTestSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.timestamps
    end

    create_table :unmagic_passkeys_credentials do |t|
      t.references :holder, polymorphic: true, null: false
      t.string :credential_id, null: false
      t.binary :public_key, null: false
      t.integer :sign_count, null: false, default: 0
      t.string :name
      t.text :transports
      t.string :aaguid
      t.boolean :backed_up
      t.timestamps

      t.index :credential_id, unique: true
    end
  end
end
