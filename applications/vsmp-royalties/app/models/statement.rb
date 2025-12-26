# == Schema Information
#
# Table name: statements
#
#  id                            :integer          not null, primary key
#  fiscal_year                   :integer
#  fiscal_quarter                :integer
#  invoiced                      :boolean          default(FALSE)
#  invoiced_at                   :datetime
#  status                        :integer          default(0), not null
#  error_message                 :text
#  started_at                    :datetime
#  completed_at                  :datetime
#  number_of_royalties_assigned  :integer
#  writer_ids                    :text
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#

class Statement < ApplicationRecord
  has_many :statement_writers, dependent: :destroy
  has_many :writers, through: :statement_writers
  has_many :royalties, dependent: :nullify
  has_many :statement_conflicts, dependent: :destroy
  has_one_attached :export_csv

  validates :fiscal_year, presence: true
  validates :fiscal_quarter, presence: true

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  serialize :writer_ids, coder: JSON

  after_create :populate_royalties_job
  after_update_commit -> { broadcast_replace_to "statements", partial: "statements/statement", locals: { statement: self } }

  before_destroy :check_if_invoiced, prepend: true

  def mark_processing!
    update!(status: :processing, started_at: Time.current)
  end

  def mark_completed!(royalties_count)
    update!(
      status: :completed,
      completed_at: Time.current,
      number_of_royalties_assigned: royalties_count
    )
  end

  def mark_failed!(error)
    update!(
      status: :failed,
      completed_at: Time.current,
      error_message: error.to_s
    )
  end

  def display_name
    "Q#{fiscal_quarter} #{fiscal_year} - #{writers.map(&:csv_name).join(', ')}"
  end

  def has_conflicts?
    statement_conflicts.where(resolved: false).exists?
  end

  def total_final_distributed_amount
    royalties.sum(:final_distributed_amount) || 0
  end

  private

  def populate_royalties_job
    PopulateStatementJob.perform_later(id)
  end

  def check_if_invoiced
    if invoiced?
      errors.add(:base, "Cannot delete invoiced statement")
      throw :abort
    end
  end
end
