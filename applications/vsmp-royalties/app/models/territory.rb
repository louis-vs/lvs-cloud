# == Schema Information
#
# Table name: territories
#
#  id         :integer          not null, primary key
#  name       :string
#  iso_code   :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Territory < ApplicationRecord
  has_many :royalties, dependent: :restrict_with_error

  validates :name, presence: true
  validates :iso_code, presence: true
end
