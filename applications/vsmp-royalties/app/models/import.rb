# == Schema Information
#
# Table name: imports
#
#  id                        :integer          not null, primary key
#  original_file_name        :string
#  fiscal_year               :integer
#  fiscal_quarter            :integer
#  number_of_royalties_added :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#

class Import < ApplicationRecord
  has_one_attached :csv_file
  has_many :royalties, dependent: :destroy_async

  validates :original_file_name, presence: true
  validates :fiscal_year, presence: true
  validates :fiscal_quarter, presence: true

  after_create :start_import_job

  private

  def start_import_job
    ImportRoyaltiesJob.perform_later(id)
  end
end
