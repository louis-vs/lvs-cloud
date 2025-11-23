class Batch < ApplicationRecord
  has_many :royalties, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
end
