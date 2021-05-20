class CreateNewAllocations < ActiveRecord::Migration[6.0]
  def change
    create_table :new_allocations do |t|
      t.references :case_information, null: false
      t.references :pom_detail, null: false
      t.string :allocation_type, null: false
      t.timestamps

      # Offenders can only have 1 'primary' POM and 1 'coworking' POM
      # Enforce this in the database with a unique composite index
      t.index [:case_information_id, :allocation_type], unique: true,
              # Index name has to be specified manually because the auto-generated name is too long for Postgres (over 63 chars)
              name: 'index_new_allocations_on_case_information_and_type'
    end
  end
end