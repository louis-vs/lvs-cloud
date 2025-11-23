class Territory < ApplicationRecord
  has_many :royalties, dependent: :restrict_with_error

  validates :name, presence: true
  validates :iso_code, presence: true
end
