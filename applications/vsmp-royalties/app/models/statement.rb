class Statement < ApplicationRecord
  has_many :statement_writers, dependent: :destroy
  has_many :writers, through: :statement_writers
  has_many :royalties, dependent: :nullify
  has_many :statement_conflicts, dependent: :destroy
  has_one_attached :export_csv

  validates :fiscal_year, presence: true
  validates :fiscal_quarter, presence: true

  after_create :populate_royalties_job

  private

  def populate_royalties_job
    # PopulateStatementJob.perform_later(id)
  end
end
