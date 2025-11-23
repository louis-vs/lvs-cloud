class CreateRightTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :right_types do |t|
      t.string :name
      t.string :group

      t.timestamps
    end
  end
end
