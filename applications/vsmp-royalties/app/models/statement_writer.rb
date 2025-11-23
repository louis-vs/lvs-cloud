class StatementWriter < ApplicationRecord
  belongs_to :statement
  belongs_to :writer
end
