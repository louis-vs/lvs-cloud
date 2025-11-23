# == Schema Information
#
# Table name: batches
#
#  id          :integer          not null, primary key
#  code        :string
#  description :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_batches_on_code  (code) UNIQUE
#

require "test_helper"

class BatchTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
