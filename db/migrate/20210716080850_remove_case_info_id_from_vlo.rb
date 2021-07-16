class RemoveCaseInfoIdFromVlo < ActiveRecord::Migration[6.0]
  def change
    remove_column :victim_liaison_officers, :case_information_id, :string
  end
end
