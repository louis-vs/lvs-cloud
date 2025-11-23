class Royalty < ApplicationRecord
  belongs_to :batch
  belongs_to :work
  belongs_to :right_type
  belongs_to :territory
  belongs_to :exploitation
  belongs_to :import
  belongs_to :statement, optional: true
end
