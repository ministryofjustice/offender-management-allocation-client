# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_05_19_153151) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "allocations", force: :cascade do |t|
    t.string "nomis_offender_id"
    t.string "prison"
    t.string "allocated_at_tier"
    t.string "override_reasons"
    t.string "override_detail"
    t.string "message"
    t.string "suitability_detail"
    t.string "primary_pom_name"
    t.string "secondary_pom_name"
    t.string "created_by_name"
    t.integer "primary_pom_nomis_id"
    t.integer "secondary_pom_nomis_id"
    t.integer "event"
    t.integer "event_trigger"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "primary_pom_allocated_at"
    t.string "recommended_pom_type"
    t.index ["nomis_offender_id"], name: "index_allocations_on_nomis_offender_id"
    t.index ["primary_pom_nomis_id"], name: "index_allocations_on_primary_pom_nomis_id"
    t.index ["prison"], name: "index_allocations_on_prison"
    t.index ["secondary_pom_nomis_id"], name: "index_allocation_versions_secondary_pom_nomis_id"
  end

  create_table "calculated_handover_dates", force: :cascade do |t|
    t.date "start_date"
    t.date "handover_date"
    t.string "reason", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "nomis_offender_id", null: false
    t.string "responsibility"
    t.index ["nomis_offender_id"], name: "index_calculated_handover_dates_on_nomis_offender_id", unique: true
  end

  create_table "case_information", force: :cascade do |t|
    t.string "tier"
    t.string "case_allocation"
    t.string "nomis_offender_id"
    t.string "crn"
    t.integer "mappa_level"
    t.boolean "manual_entry", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date "parole_review_date"
    t.string "probation_service"
    t.string "com_name"
    t.string "team_name"
    t.bigint "local_delivery_unit_id"
    t.index ["local_delivery_unit_id"], name: "index_case_information_on_local_delivery_unit_id"
    t.index ["nomis_offender_id"], name: "index_case_information_on_nomis_offender_id", unique: true
  end

  create_table "contact_submissions", force: :cascade do |t|
    t.text "message", null: false
    t.string "email_address"
    t.string "referrer"
    t.string "user_agent"
    t.string "prison"
    t.string "name"
    t.string "job_type"
  end

  create_table "delius_import_errors", force: :cascade do |t|
    t.string "nomis_offender_id"
    t.integer "error_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "early_allocations", force: :cascade do |t|
    t.string "nomis_offender_id", null: false
    t.date "oasys_risk_assessment_date", null: false
    t.boolean "convicted_under_terrorisom_act_2000", null: false
    t.boolean "high_profile", null: false
    t.boolean "serious_crime_prevention_order", null: false
    t.boolean "mappa_level_3", null: false
    t.boolean "cppc_case", null: false
    t.boolean "high_risk_of_serious_harm"
    t.boolean "mappa_level_2"
    t.boolean "pathfinder_process"
    t.boolean "other_reason"
    t.boolean "extremism_separation"
    t.boolean "due_for_release_in_less_than_24months"
    t.boolean "approved"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "community_decision"
    t.string "prison"
    t.string "created_by_firstname"
    t.string "created_by_lastname"
    t.string "updated_by_firstname"
    t.string "updated_by_lastname"
    t.boolean "created_within_referral_window", default: false, null: false
    t.string "outcome", null: false
  end

  create_table "email_histories", force: :cascade do |t|
    t.string "prison", null: false
    t.string "nomis_offender_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "event", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "flipflop_features", force: :cascade do |t|
    t.string "key", null: false
    t.boolean "enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "local_delivery_units", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "country", null: false
    t.boolean "enabled", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["code"], name: "index_local_delivery_units_on_code", unique: true
  end

  create_table "new_allocations", force: :cascade do |t|
    t.bigint "case_information_id", null: false
    t.bigint "pom_detail_id", null: false
    t.string "allocation_type", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["case_information_id", "allocation_type"], name: "index_new_allocations_on_case_information_and_type", unique: true
    t.index ["case_information_id"], name: "index_new_allocations_on_case_information_id"
    t.index ["pom_detail_id"], name: "index_new_allocations_on_pom_detail_id"
  end

  create_table "offender_events", force: :cascade do |t|
    t.string "nomis_offender_id", null: false
    t.string "event", null: false
    t.datetime "happened_at", null: false
    t.string "triggered_by", null: false
    t.string "triggered_by_nomis_username"
    t.jsonb "metadata"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["nomis_offender_id"], name: "index_offender_events_on_nomis_offender_id"
  end

  create_table "overrides", force: :cascade do |t|
    t.integer "nomis_staff_id"
    t.string "nomis_offender_id"
    t.string "override_reasons"
    t.string "more_detail"
    t.string "suitability_detail"
  end

  create_table "pom_details", force: :cascade do |t|
    t.integer "nomis_staff_id"
    t.float "working_pattern"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "prison_code"
    t.index ["nomis_staff_id", "prison_code"], name: "index_pom_details_on_nomis_staff_id_and_prison_code", unique: true
  end

  create_table "responsibilities", force: :cascade do |t|
    t.string "nomis_offender_id", null: false
    t.integer "reason", null: false
    t.string "reason_text"
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at"
    t.text "object_changes"
    t.string "nomis_offender_id"
    t.string "user_first_name"
    t.string "user_last_name"
    t.string "prison"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["nomis_offender_id"], name: "index_versions_on_nomis_offender_id"
  end

  create_table "victim_liaison_officers", force: :cascade do |t|
    t.bigint "case_information_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["case_information_id"], name: "index_victim_liaison_officers_on_case_information_id"
  end

  add_foreign_key "calculated_handover_dates", "case_information", column: "nomis_offender_id", primary_key: "nomis_offender_id", on_update: :cascade, on_delete: :cascade
end
