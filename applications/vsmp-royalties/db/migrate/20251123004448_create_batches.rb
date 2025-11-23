class CreateBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :batches do |t|
      t.string :code
      t.text :description

      t.timestamps
    end
    add_index :batches, :code, unique: true
  end
end
