class AddStatusToStatements < ActiveRecord::Migration[8.1]
  def change
    add_column :statements, :status, :integer, default: 0, null: false
    add_column :statements, :error_message, :text
    add_column :statements, :started_at, :datetime
    add_column :statements, :completed_at, :datetime
    add_column :statements, :number_of_royalties_assigned, :integer
  end
end
