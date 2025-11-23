class CreateRoyalties < ActiveRecord::Migration[8.1]
  def change
    create_table :royalties do |t|
      t.references :batch, null: false, foreign_key: true
      t.references :work, null: false, foreign_key: true
      t.references :right_type, null: false, foreign_key: true
      t.references :territory, null: false, foreign_key: true
      t.references :exploitation, null: true, foreign_key: true
      t.references :import, null: false, foreign_key: true
      t.references :statement, null: true, foreign_key: true
      t.string :agreement_code
      t.string :custom_work_id
      t.decimal :distributed_amount
      t.decimal :final_distributed_amount
      t.decimal :percentage_paid
      t.decimal :unit_sum
      t.decimal :wht_adj_received_amount
      t.decimal :wht_adj_source_amount
      t.decimal :direct_collect_fee_taken
      t.decimal :direct_collected_amount
      t.string :credit_or_debit
      t.string :recording_artist
      t.string :av_production_title
      t.date :period_start
      t.date :period_end
      t.string :source_name
      t.string :revenue_source_name
      t.string :generated_at_cover_rate

      t.timestamps
    end

    add_index :royalties, [ :import_id, :work_id ]
  end
end
