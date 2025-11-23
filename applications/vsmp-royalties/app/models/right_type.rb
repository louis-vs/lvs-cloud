# == Schema Information
#
# Table name: right_types
#
#  id         :integer          not null, primary key
#  name       :string
#  group      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class RightType < ApplicationRecord
  has_many :royalties, dependent: :restrict_with_error

  validates :name, presence: true
  validates :group, presence: true
end
