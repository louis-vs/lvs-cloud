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
  # test "the truth" do
  #   assert true
  # end
end
