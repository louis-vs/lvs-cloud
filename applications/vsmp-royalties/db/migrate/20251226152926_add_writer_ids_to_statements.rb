class AddWriterIdsToStatements < ActiveRecord::Migration[8.1]
  def change
    add_column :statements, :writer_ids, :text
  end
end
