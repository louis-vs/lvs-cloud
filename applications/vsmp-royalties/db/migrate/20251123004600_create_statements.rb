class CreateStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :statements do |t|
      t.integer :fiscal_year
      t.integer :fiscal_quarter
      t.boolean :invoiced, default: false
      t.datetime :invoiced_at

      t.timestamps
    end
  end
end
