# == Schema Information
#
# Table name: royalties
#
#  id                       :integer          not null, primary key
#  batch_id                 :integer          not null
#  work_id                  :integer          not null
#  right_type_id            :integer          not null
#  territory_id             :integer          not null
#  exploitation_id          :integer          not null
#  import_id                :integer          not null
#  statement_id             :integer
#  agreement_code           :string
#  custom_work_id           :string
#  distributed_amount       :decimal(20, 18)
#  final_distributed_amount :decimal(20, 18)
#  percentage_paid          :decimal(20, 18)
#  unit_sum                 :decimal(20, 18)
#  wht_adj_received_amount  :decimal(20, 18)
#  wht_adj_source_amount    :decimal(20, 18)
#  direct_collect_fee_taken :decimal(20, 18)
#  direct_collected_amount  :decimal(20, 18)
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

require "test_helper"

class RoyaltyTest < ActiveSupport::TestCase
  test "should belong to batch, work, right_type, territory, exploitation, and import" do
    royalty = Royalty.new
    assert_not royalty.valid?
    assert_includes royalty.errors[:batch], "must exist"
    assert_includes royalty.errors[:work], "must exist"
    assert_includes royalty.errors[:right_type], "must exist"
    assert_includes royalty.errors[:territory], "must exist"
    assert_includes royalty.errors[:exploitation], "must exist"
    assert_includes royalty.errors[:import], "must exist"
  end

  test "should allow optional statement" do
    batch = Batch.create!(code: "B123")
    work = Work.create!(work_id: "W123", title: "Test Work")
    right_type = RightType.create!(name: "Performance", group: "PERF")
    territory = Territory.create!(name: "United Kingdom", iso_code: "GB")
    exploitation = Exploitation.create!
    import = Import.create!(original_file_name: "test.csv", fiscal_year: 2024, fiscal_quarter: 1)

    royalty = Royalty.new(
      batch: batch,
      work: work,
      right_type: right_type,
      territory: territory,
      exploitation: exploitation,
      import: import
    )

    assert royalty.valid?
    assert_nil royalty.statement
  end
end
