class CreateWriters < ActiveRecord::Migration[8.1]
  def change
    create_table :writers do |t|
      t.string :first_name
      t.string :last_name
      t.string :ip_code

      t.timestamps
    end
    add_index :writers, :ip_code, unique: true
  end
end
