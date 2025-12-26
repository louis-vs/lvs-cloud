class PopulateStatementJob < ApplicationJob
  queue_as :default

  def perform(statement_id)
    statement = Statement.find(statement_id)
    statement.mark_processing!

    # Find matching royalties
    royalties = find_matching_royalties(statement)

    # Assign royalties and apply coefficients in transaction
    royalties_count = 0
    conflicts = []

    Royalty.transaction do
      royalties.each do |royalty|
        # Detect conflicts
        if royalty.statement_id.present? && royalty.statement_id != statement.id
          conflicts << {
            royalty_id: royalty.id,
            conflicting_statement_id: royalty.statement_id
          }
        end

        # Apply coefficient and assign to statement
        coefficient = calculate_coefficient(royalty.right_type)
        royalty.update!(
          statement_id: statement.id,
          final_distributed_amount: (royalty.distributed_amount || 0) * coefficient
        )
        royalties_count += 1
      end

      # Create conflict records
      conflicts.each do |conflict|
        StatementConflict.create!(
          statement: statement,
          royalty_id: conflict[:royalty_id],
          conflicting_statement_id: conflict[:conflicting_statement_id]
        )
      end
    end

    statement.mark_completed!(royalties_count)

    # Trigger export job
    ExportStatementJob.perform_later(statement_id)
  rescue => e
    statement.mark_failed!(e)
    raise
  end

  private

  def find_matching_royalties(statement)
    # Get royalties matching:
    # 1. Fiscal period (from import)
    # 2. Writers (from statement)
    # 3. Not already assigned to this statement

    writer_ids = statement.writer_ids

    Royalty.joins(:import, work: :writers)
           .where(imports: {
             fiscal_year: statement.fiscal_year,
             fiscal_quarter: statement.fiscal_quarter
           })
           .where(writers: { id: writer_ids })
           .where.not(statement_id: statement.id)
           .distinct
  end

  def calculate_coefficient(right_type)
    case right_type.group
    when "MECH", "PRINT"
      BigDecimal("0.8")
    when "SYNC"
      BigDecimal("0.7")
    when "PERF"
      BigDecimal("0.6")
    else
      BigDecimal("1.0")
    end
  end
end
