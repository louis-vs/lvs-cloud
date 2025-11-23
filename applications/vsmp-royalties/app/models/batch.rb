# == Schema Information
#
# Table name: batches
#
#  id          :integer          not null, primary key
#  code        :string
#  description :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_batches_on_code  (code) UNIQUE
#

class Batch < ApplicationRecord
  has_many :royalties, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
end
