# == Schema Information
#
# Table name: imports
#
#  id                        :integer          not null, primary key
#  original_file_name        :string
#  fiscal_year               :integer
#  fiscal_quarter            :integer
#  number_of_royalties_added :integer
#  status                    :integer          default("pending"), not null
#  error_message             :text
#  started_at                :datetime
#  completed_at              :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#

class Import < ApplicationRecord
  has_one_attached :csv_file
  has_many :royalties, dependent: :destroy

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  validates :original_file_name, presence: true
  validates :fiscal_year, presence: true
  validates :fiscal_quarter, presence: true

  after_create :start_import_job
  after_update_commit -> { broadcast_replace_to "imports", partial: "imports/import", locals: { import: self } }
  before_destroy :check_for_assigned_royalties, prepend: true

  def display_name
    "#{original_file_name} (Q#{fiscal_quarter} #{fiscal_year})"
  end

  def mark_processing!
    update!(status: :processing, started_at: Time.current)
  end

  def mark_completed!(royalties_count)
    update!(
      status: :completed,
      completed_at: Time.current,
      number_of_royalties_added: royalties_count
    )
  end

  def mark_failed!(error)
    update!(
      status: :failed,
      completed_at: Time.current,
      error_message: error.to_s
    )
  end

  private

  def start_import_job
    ImportRoyaltiesJob.perform_later(id)
  end

  def check_for_assigned_royalties
    assigned_count = royalties.where.not(statement_id: nil).count
    if assigned_count > 0
      errors.add(:base, "Cannot rollback import: #{assigned_count} royalties have been assigned to statements")
      throw :abort
    end
  end
end
