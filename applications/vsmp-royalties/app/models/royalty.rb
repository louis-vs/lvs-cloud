# == Schema Information
#
# Table name: royalties
#
#  id                       :integer          not null, primary key
#  batch_id                 :integer          not null
#  work_id                  :integer          not null
#  right_type_id            :integer          not null
#  territory_id             :integer          not null
#  exploitation_id          :integer
#  import_id                :integer          not null
#  statement_id             :integer
#  agreement_code           :string
#  custom_work_id           :string
#  distributed_amount       :decimal(, )
#  final_distributed_amount :decimal(, )
#  percentage_paid          :decimal(, )
#  unit_sum                 :decimal(, )
#  wht_adj_received_amount  :decimal(, )
#  wht_adj_source_amount    :decimal(, )
#  direct_collect_fee_taken :decimal(, )
#  direct_collected_amount  :decimal(, )
#  credit_or_debit          :string
#  recording_artist         :string
#  av_production_title      :string
#  period_start             :date
#  period_end               :date
#  source_name              :string
#  revenue_source_name      :string
#  generated_at_cover_rate  :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_royalties_on_batch_id               (batch_id)
#  index_royalties_on_exploitation_id        (exploitation_id)
#  index_royalties_on_import_id              (import_id)
#  index_royalties_on_import_id_and_work_id  (import_id,work_id)
#  index_royalties_on_right_type_id          (right_type_id)
#  index_royalties_on_statement_id           (statement_id)
#  index_royalties_on_territory_id           (territory_id)
#  index_royalties_on_work_id                (work_id)
#

class Royalty < ApplicationRecord
  belongs_to :batch
  belongs_to :work
  belongs_to :right_type
  belongs_to :territory
  belongs_to :exploitation, optional: true
  belongs_to :import
  belongs_to :statement, optional: true
end
