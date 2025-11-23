# == Schema Information
#
# Table name: writers
#
#  id         :integer          not null, primary key
#  first_name :string
#  last_name  :string
#  ip_code    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_writers_on_ip_code  (ip_code) UNIQUE
#

class Writer < ApplicationRecord
  has_many :work_writers, dependent: :destroy
  has_many :works, through: :work_writers
  has_many :statement_writers, dependent: :destroy
  has_many :statements, through: :statement_writers

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :ip_code, presence: true, uniqueness: true

  def csv_name
    "#{last_name}, #{first_name} [#{ip_code}]"
  end
end
