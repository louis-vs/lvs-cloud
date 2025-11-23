class CreateWorkWriters < ActiveRecord::Migration[8.1]
  def change
    create_table :work_writers do |t|
      t.references :work, null: false, foreign_key: true
      t.references :writer, null: false, foreign_key: true

      t.timestamps
    end
  end
end
