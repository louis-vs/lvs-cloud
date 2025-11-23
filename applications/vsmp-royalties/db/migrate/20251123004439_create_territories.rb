class CreateTerritories < ActiveRecord::Migration[8.1]
  def change
    create_table :territories do |t|
      t.string :name
      t.string :iso_code

      t.timestamps
    end
  end
end
