# == Schema Information
#
# Table name: statements
#
#  id             :integer          not null, primary key
#  fiscal_year    :integer
#  fiscal_quarter :integer
#  invoiced       :boolean          default(FALSE)
#  invoiced_at    :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#

require "test_helper"

class StatementTest < ActiveSupport::TestCase
  test "should require fiscal_year" do
    statement = Statement.new(fiscal_quarter: 1)
    assert_not statement.valid?
    assert_includes statement.errors[:fiscal_year], "can't be blank"
  end

  test "should require fiscal_quarter" do
    statement = Statement.new(fiscal_year: 2024)
    assert_not statement.valid?
    assert_includes statement.errors[:fiscal_quarter], "can't be blank"
  end

  test "should default invoiced to false" do
    statement = Statement.create!(fiscal_year: 2024, fiscal_quarter: 1)
    assert_equal false, statement.invoiced
  end

  test "should have many writers through statement_writers" do
    statement = Statement.create!(fiscal_year: 2024, fiscal_quarter: 1)
    writer1 = Writer.create!(first_name: "John", last_name: "Doe", ip_code: "IP123")
    writer2 = Writer.create!(first_name: "Jane", last_name: "Smith", ip_code: "IP456")

    statement.writers << writer1
    statement.writers << writer2

    assert_equal 2, statement.writers.count
    assert_includes statement.writers, writer1
    assert_includes statement.writers, writer2
  end
end
