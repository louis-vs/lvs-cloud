# == Schema Information
#
# Table name: statement_conflicts
#
#  id                       :integer          not null, primary key
#  statement_id             :integer          not null
#  royalty_id               :integer
#  conflicting_statement_id :integer
#  resolved                 :boolean          default(FALSE)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_statement_conflicts_on_statement_id  (statement_id)
#

class StatementConflict < ApplicationRecord
  belongs_to :statement
end
