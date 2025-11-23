class CreateStatementConflicts < ActiveRecord::Migration[8.1]
  def change
    create_table :statement_conflicts do |t|
      t.references :statement, null: false, foreign_key: true
      t.bigint :royalty_id
      t.bigint :conflicting_statement_id
      t.boolean :resolved, default: false

      t.timestamps
    end
  end
end
