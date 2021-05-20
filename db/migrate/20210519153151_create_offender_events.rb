class CreateOffenderEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :offender_events do |t|
      t.string :nomis_offender_id, null: false, index: true
      t.string :event, null: false
      t.datetime :happened_at, null: false
      t.string :triggered_by, null: false
      t.string :triggered_by_nomis_username
      t.jsonb :metadata

      t.timestamps
    end
  end
end
