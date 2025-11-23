class Work < ApplicationRecord
  has_many :work_writers, dependent: :destroy
  has_many :writers, through: :work_writers
  has_many :royalties, dependent: :restrict_with_error

  validates :work_id, presence: true
  validates :title, presence: true
end
