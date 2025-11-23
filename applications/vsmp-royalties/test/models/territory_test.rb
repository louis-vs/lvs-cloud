# == Schema Information
#
# Table name: territories
#
#  id         :integer          not null, primary key
#  name       :string
#  iso_code   :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

require "test_helper"

class TerritoryTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
