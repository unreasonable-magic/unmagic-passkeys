# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_01_000001) do
  create_table "unmagic_passkeys_credentials", force: :cascade do |t|
    t.string "aaguid"
    t.boolean "backed_up"
    t.datetime "created_at", null: false
    t.string "credential_id", null: false
    t.integer "holder_id", null: false
    t.string "holder_type", null: false
    t.string "name"
    t.binary "public_key", null: false
    t.integer "sign_count", default: 0, null: false
    t.text "transports"
    t.datetime "updated_at", null: false
    t.index [ "credential_id" ], name: "index_unmagic_passkeys_credentials_on_credential_id", unique: true
    t.index [ "holder_type", "holder_id" ], name: "index_unmagic_passkeys_credentials_on_holder"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "updated_at", null: false
  end
end
