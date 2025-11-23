# == Schema Information
#
# Table name: imports
#
#  id                        :integer          not null, primary key
#  original_file_name        :string
#  fiscal_year               :integer
#  fiscal_quarter            :integer
#  number_of_royalties_added :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#

require "test_helper"

class ImportTest < ActiveSupport::TestCase
  test "can destroy import with no assigned royalties" do
    import = imports(:one)

    # Ensure royalties exist but are not assigned to statements
    royalty = import.royalties.create!(
      batch: batches(:one),
      work: works(:one),
      right_type: right_types(:one),
      territory: territories(:one),
      distributed_amount: 100.00
    )

    assert_difference "Import.count", -1 do
      assert_difference "Royalty.count", -1 do
        assert import.destroy
      end
    end
  end

  test "cannot destroy import with assigned royalties" do
    import = imports(:one)
    statement = statements(:one)

    # Create a royalty assigned to a statement
    royalty = import.royalties.create!(
      batch: batches(:one),
      work: works(:one),
      right_type: right_types(:one),
      territory: territories(:one),
      statement: statement,
      distributed_amount: 100.00
    )

    assert_no_difference "Import.count" do
      assert_no_difference "Royalty.count" do
        result = import.destroy
        assert_equal false, result
      end
    end

    assert_includes import.errors[:base], "Cannot rollback import: 1 royalties have been assigned to statements"
  end
end
