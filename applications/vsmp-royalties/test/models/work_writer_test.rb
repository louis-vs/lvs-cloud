# == Schema Information
#
# Table name: work_writers
#
#  id         :integer          not null, primary key
#  work_id    :integer          not null
#  writer_id  :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_work_writers_on_work_id    (work_id)
#  index_work_writers_on_writer_id  (writer_id)
#

require "test_helper"

class WorkWriterTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
