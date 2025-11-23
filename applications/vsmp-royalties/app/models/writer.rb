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
