class CreateCalculatedEarlyAllocationStatus < ActiveRecord::Migration[6.0]
  def change
    create_table :calculated_early_allocation_statuses, id: false do |t|
      t.string :nomis_offender_id, primary_key: true
      t.boolean :eligible, null: false

      t.timestamps
    end
  end
end
