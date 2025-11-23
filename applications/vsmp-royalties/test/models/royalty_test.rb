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
