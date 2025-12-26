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

ActiveRecord::Schema[8.1].define(version: 2025_12_26_152926) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "batches", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_batches_on_code", unique: true
  end

  create_table "exploitations", force: :cascade do |t|
    t.string "artist"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "format"
    t.string "licence_id"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "imports", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "fiscal_quarter"
    t.integer "fiscal_year"
    t.integer "number_of_royalties_added"
    t.string "original_file_name"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "right_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "group"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "royalties", force: :cascade do |t|
    t.string "agreement_code"
    t.string "av_production_title"
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.string "credit_or_debit"
    t.string "custom_work_id"
    t.decimal "direct_collect_fee_taken"
    t.decimal "direct_collected_amount"
    t.decimal "distributed_amount"
    t.bigint "exploitation_id"
    t.decimal "final_distributed_amount"
    t.string "generated_at_cover_rate"
    t.bigint "import_id", null: false
    t.decimal "percentage_paid"
    t.date "period_end"
    t.date "period_start"
    t.string "recording_artist"
    t.string "revenue_source_name"
    t.bigint "right_type_id", null: false
    t.string "source_name"
    t.bigint "statement_id"
    t.bigint "territory_id", null: false
    t.decimal "unit_sum"
    t.datetime "updated_at", null: false
    t.decimal "wht_adj_received_amount"
    t.decimal "wht_adj_source_amount"
    t.bigint "work_id", null: false
    t.index ["batch_id"], name: "index_royalties_on_batch_id"
    t.index ["exploitation_id"], name: "index_royalties_on_exploitation_id"
    t.index ["import_id", "work_id"], name: "index_royalties_on_import_id_and_work_id"
    t.index ["import_id"], name: "index_royalties_on_import_id"
    t.index ["right_type_id"], name: "index_royalties_on_right_type_id"
    t.index ["statement_id"], name: "index_royalties_on_statement_id"
    t.index ["territory_id"], name: "index_royalties_on_territory_id"
    t.index ["work_id"], name: "index_royalties_on_work_id"
  end

  create_table "statement_conflicts", force: :cascade do |t|
    t.bigint "conflicting_statement_id"
    t.datetime "created_at", null: false
    t.boolean "resolved", default: false
    t.bigint "royalty_id"
    t.bigint "statement_id", null: false
    t.datetime "updated_at", null: false
    t.index ["statement_id"], name: "index_statement_conflicts_on_statement_id"
  end

  create_table "statement_writers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "statement_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "writer_id", null: false
    t.index ["statement_id"], name: "index_statement_writers_on_statement_id"
    t.index ["writer_id"], name: "index_statement_writers_on_writer_id"
  end

  create_table "statements", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "fiscal_quarter"
    t.integer "fiscal_year"
    t.boolean "invoiced", default: false
    t.datetime "invoiced_at"
    t.integer "number_of_royalties_assigned"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.text "writer_ids"
  end

  create_table "territories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "iso_code"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "work_writers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "work_id", null: false
    t.bigint "writer_id", null: false
    t.index ["work_id"], name: "index_work_writers_on_work_id"
    t.index ["writer_id"], name: "index_work_writers_on_writer_id"
  end

  create_table "works", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "work_id"
    t.index ["work_id"], name: "index_works_on_work_id"
  end

  create_table "writers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "first_name"
    t.string "ip_code"
    t.string "last_name"
    t.datetime "updated_at", null: false
    t.index ["ip_code"], name: "index_writers_on_ip_code", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "royalties", "batches"
  add_foreign_key "royalties", "exploitations"
  add_foreign_key "royalties", "imports"
  add_foreign_key "royalties", "right_types"
  add_foreign_key "royalties", "statements"
  add_foreign_key "royalties", "territories"
  add_foreign_key "royalties", "works"
  add_foreign_key "statement_conflicts", "statements"
  add_foreign_key "statement_writers", "statements"
  add_foreign_key "statement_writers", "writers"
  add_foreign_key "work_writers", "works"
  add_foreign_key "work_writers", "writers"
end
