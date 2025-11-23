class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.string :original_file_name
      t.integer :fiscal_year
      t.integer :fiscal_quarter
      t.integer :number_of_royalties_added
      t.integer :status, default: 0, null: false
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
