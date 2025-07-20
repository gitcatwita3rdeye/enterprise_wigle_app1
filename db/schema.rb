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

ActiveRecord::Schema[8.0].define(version: 2025_07_20_211910) do
  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "network_observations", force: :cascade do |t|
    t.integer "wifi_network_id", null: false
    t.integer "wardrive_session_id", null: false
    t.decimal "latitude"
    t.decimal "longitude"
    t.decimal "altitude"
    t.integer "signal_strength"
    t.datetime "timestamp"
    t.decimal "gps_accuracy"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["wardrive_session_id"], name: "index_network_observations_on_wardrive_session_id"
    t.index ["wifi_network_id"], name: "index_network_observations_on_wifi_network_id"
  end

  create_table "wardrive_sessions", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "user_name"
    t.text "device_info"
    t.integer "total_networks"
    t.integer "unique_networks"
    t.decimal "distance_covered"
    t.string "file_format"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.index ["slug"], name: "index_wardrive_sessions_on_slug"
  end

  create_table "wifi_networks", force: :cascade do |t|
    t.string "ssid"
    t.string "bssid"
    t.string "encryption"
    t.integer "frequency"
    t.integer "channel"
    t.integer "signal_strength"
    t.decimal "latitude"
    t.decimal "longitude"
    t.decimal "altitude"
    t.decimal "accuracy"
    t.datetime "timestamp"
    t.string "vendor"
    t.text "capabilities"
    t.datetime "first_seen"
    t.datetime "last_seen"
    t.integer "observation_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.index ["slug"], name: "index_wifi_networks_on_slug"
  end

  add_foreign_key "network_observations", "wardrive_sessions"
  add_foreign_key "network_observations", "wifi_networks"
end
