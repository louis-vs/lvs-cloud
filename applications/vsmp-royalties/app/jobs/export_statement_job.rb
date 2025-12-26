require "csv"

class ExportStatementJob < ApplicationJob
  queue_as :default

  def perform(statement_id)
    statement = Statement.find(statement_id)

    # Generate CSV
    csv_data = generate_csv(statement)

    # Create temporary file
    temp_file = Tempfile.new([ "statement_#{statement.id}", ".csv" ])
    temp_file.write(csv_data)
    temp_file.rewind

    # Attach to statement
    statement.export_csv.attach(
      io: temp_file,
      filename: "statement_Q#{statement.fiscal_quarter}_#{statement.fiscal_year}_#{statement.id}.csv",
      content_type: "text/csv"
    )

    temp_file.close
    temp_file.unlink

    # Broadcast update to refresh download link
    statement.touch
  end

  private

  def generate_csv(statement)
    CSV.generate(headers: true) do |csv|
      # Header row
      csv << [
        "WORK_ID",
        "WORK_TITLE",
        "WRITERS",
        "RIGHT_TYPE",
        "RIGHT_TYPE_GROUP",
        "TERRITORY",
        "BATCH_ID",
        "DISTRIBUTED_AMOUNT",
        "COEFFICIENT",
        "FINAL_DISTRIBUTED_AMOUNT",
        "PERIOD_START",
        "PERIOD_END",
        "RECORDING_ARTIST",
        "SOURCE_NAME"
      ]

      # Data rows
      total_distributed = BigDecimal("0")
      total_final = BigDecimal("0")

      statement.royalties.includes(:work, :right_type, :territory, :batch, work: :writers).each do |royalty|
        distributed = royalty.distributed_amount || 0
        final = royalty.final_distributed_amount || 0
        coefficient = distributed > 0 ? final / distributed : BigDecimal("0")

        csv << [
          royalty.work.work_id,
          royalty.work.title,
          royalty.work.writers.map(&:csv_name).join("; "),
          royalty.right_type.name,
          royalty.right_type.group,
          royalty.territory.name,
          royalty.batch.code,
          format_decimal(distributed),
          format_decimal(coefficient),
          format_decimal(final),
          royalty.period_start&.strftime("%Y-%m-%d"),
          royalty.period_end&.strftime("%Y-%m-%d"),
          royalty.recording_artist,
          royalty.source_name
        ]

        total_distributed += distributed
        total_final += final
      end

      # Totals row
      csv << [
        "TOTAL",
        "",
        "",
        "",
        "",
        "",
        "",
        format_decimal(total_distributed),
        "",
        format_decimal(total_final),
        "",
        "",
        "",
        ""
      ]
    end
  end

  def format_decimal(value)
    return "" if value.nil?
    "%.2f" % value
  end
end
