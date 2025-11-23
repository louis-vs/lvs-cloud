class CreateStatementWriters < ActiveRecord::Migration[8.1]
  def change
    create_table :statement_writers do |t|
      t.references :statement, null: false, foreign_key: true
      t.references :writer, null: false, foreign_key: true

      t.timestamps
    end
  end
end
