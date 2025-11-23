# == Schema Information
#
# Table name: statement_writers
#
#  id           :integer          not null, primary key
#  statement_id :integer          not null
#  writer_id    :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_statement_writers_on_statement_id  (statement_id)
#  index_statement_writers_on_writer_id     (writer_id)
#

class StatementWriter < ApplicationRecord
  belongs_to :statement
  belongs_to :writer
end
