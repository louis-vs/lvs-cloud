# == Schema Information
#
# Table name: works
#
#  id         :integer          not null, primary key
#  work_id    :string
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_works_on_work_id  (work_id)
#

class Work < ApplicationRecord
  has_many :work_writers, dependent: :destroy
  has_many :writers, through: :work_writers
  has_many :royalties, dependent: :restrict_with_error

  validates :work_id, presence: true
  validates :title, presence: true
end
