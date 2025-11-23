class CreateWorks < ActiveRecord::Migration[8.1]
  def change
    create_table :works do |t|
      t.string :work_id
      t.string :title

      t.timestamps
    end
    add_index :works, :work_id
  end
end
