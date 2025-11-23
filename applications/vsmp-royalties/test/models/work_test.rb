# == Schema Information
#
# Table name: works
#
#  id         :integer          not null, primary key
#  work_id    :string
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_works_on_work_id  (work_id)
#

require "test_helper"

class WorkTest < ActiveSupport::TestCase
  test "should require work_id" do
    work = Work.new(title: "Test Work")
    assert_not work.valid?
    assert_includes work.errors[:work_id], "can't be blank"
  end

  test "should require title" do
    work = Work.new(work_id: "W123")
    assert_not work.valid?
    assert_includes work.errors[:title], "can't be blank"
  end

  test "should have many writers through work_writers" do
    work = Work.create!(work_id: "W123", title: "Test Work")
    writer1 = Writer.create!(first_name: "John", last_name: "Doe", ip_code: "IP123")
    writer2 = Writer.create!(first_name: "Jane", last_name: "Smith", ip_code: "IP456")

    work.writers << writer1
    work.writers << writer2

    assert_equal 2, work.writers.count
    assert_includes work.writers, writer1
    assert_includes work.writers, writer2
  end
end
