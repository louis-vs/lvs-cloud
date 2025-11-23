class RightType < ApplicationRecord
  has_many :royalties, dependent: :restrict_with_error

  validates :name, presence: true
  validates :group, presence: true
end
