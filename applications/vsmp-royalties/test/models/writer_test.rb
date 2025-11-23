# == Schema Information
#
# Table name: writers
#
#  id         :integer          not null, primary key
#  first_name :string
#  last_name  :string
#  ip_code    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_writers_on_ip_code  (ip_code) UNIQUE
#

require "test_helper"

class WriterTest < ActiveSupport::TestCase
  test "should require first_name" do
    writer = Writer.new(last_name: "Doe", ip_code: "IP123")
    assert_not writer.valid?
    assert_includes writer.errors[:first_name], "can't be blank"
  end

  test "should require last_name" do
    writer = Writer.new(first_name: "John", ip_code: "IP123")
    assert_not writer.valid?
    assert_includes writer.errors[:last_name], "can't be blank"
  end

  test "should require ip_code" do
    writer = Writer.new(first_name: "John", last_name: "Doe")
    assert_not writer.valid?
    assert_includes writer.errors[:ip_code], "can't be blank"
  end

  test "should require unique ip_code" do
    Writer.create!(first_name: "John", last_name: "Doe", ip_code: "IP123")
    writer = Writer.new(first_name: "Jane", last_name: "Smith", ip_code: "IP123")
    assert_not writer.valid?
    assert_includes writer.errors[:ip_code], "has already been taken"
  end

  test "csv_name should format correctly" do
    writer = Writer.new(first_name: "John", last_name: "Doe", ip_code: "IP123")
    assert_equal "Doe, John [IP123]", writer.csv_name
  end
end
