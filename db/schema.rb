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

ActiveRecord::Schema[8.1].define(version: 2026_09_03_012921) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "club_members", force: :cascade do |t|
    t.string "club_tier"
    t.string "commerce7_customer_id", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "joined_at"
    t.string "name"
    t.string "status"
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "club_tier"], name: "index_club_members_on_tenant_id_and_club_tier"
    t.index ["tenant_id", "commerce7_customer_id"], name: "index_club_members_on_tenant_id_and_commerce7_customer_id", unique: true
    t.index ["tenant_id", "status"], name: "index_club_members_on_tenant_id_and_status"
    t.index ["tenant_id"], name: "index_club_members_on_tenant_id"
  end

  create_table "order_summaries", force: :cascade do |t|
    t.string "commerce7_customer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_order_at"
    t.bigint "lifetime_value_cents", default: 0, null: false
    t.integer "order_count", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "commerce7_customer_id"], name: "index_order_summaries_on_tenant_id_and_commerce7_customer_id", unique: true
    t.index ["tenant_id", "last_order_at"], name: "index_order_summaries_on_tenant_id_and_last_order_at"
    t.index ["tenant_id"], name: "index_order_summaries_on_tenant_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.datetime "activated_at"
    t.string "commerce7_tenant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.string "name"
    t.jsonb "raw_activation_payload", default: {}, null: false
    t.jsonb "tier_color_overrides", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["commerce7_tenant_id"], name: "index_tenants_on_commerce7_tenant_id", unique: true
  end

  add_foreign_key "club_members", "tenants"
  add_foreign_key "order_summaries", "tenants"
end
