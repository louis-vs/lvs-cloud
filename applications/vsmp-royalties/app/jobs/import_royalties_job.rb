require "csv"

class ImportRoyaltiesJob < ApplicationJob
  queue_as :default

  def perform(import_id)
    import = Import.find(import_id)

    # Download CSV file from ActiveStorage
    csv_data = import.csv_file.download
    parsed_csv = CSV.parse(csv_data, headers: true)

    # Validation pass: collect all errors
    errors = validate_csv(parsed_csv)
    if errors.any?
      raise StandardError, "CSV validation failed: #{errors.join(', ')}"
    end

    # Import pass: single transaction
    royalties_count = 0
    Royalty.transaction do
      parsed_csv.each do |row|
        royalty = build_royalty_from_row(row, import)
        royalty.save!
        royalties_count += 1
      end

      import.update!(number_of_royalties_added: royalties_count)
    end
  end

  private

  def validate_csv(parsed_csv)
    errors = []

    parsed_csv.each_with_index do |row, index|
      line_number = index + 2 # +2 because CSV is 1-indexed and we skip header

      # Validate required fields
      if row["WORK_ID"].blank?
        errors << "Line #{line_number}: WORK_ID is required"
      end

      if row["BATCH_ID"].blank?
        errors << "Line #{line_number}: BATCH_ID is required"
      end

      # Validate numeric fields
      if row["DISTRIBUTED_AMOUNT"].present?
        begin
          BigDecimal(row["DISTRIBUTED_AMOUNT"])
        rescue ArgumentError
          errors << "Line #{line_number}: DISTRIBUTED_AMOUNT must be numeric"
        end
      end

      if row["PERCENTAGE_PAID"].present?
        begin
          BigDecimal(row["PERCENTAGE_PAID"])
        rescue ArgumentError
          errors << "Line #{line_number}: PERCENTAGE_PAID must be numeric"
        end
      end

      # Validate dates
      if row["ROYALTY_PERIOD_START_DATE"].present?
        begin
          Date.parse(row["ROYALTY_PERIOD_START_DATE"])
        rescue Date::Error
          errors << "Line #{line_number}: ROYALTY_PERIOD_START_DATE is invalid"
        end
      end

      if row["ROYALTY_PERIOD_END_DATE"].present?
        begin
          Date.parse(row["ROYALTY_PERIOD_END_DATE"])
        rescue Date::Error
          errors << "Line #{line_number}: ROYALTY_PERIOD_END_DATE is invalid"
        end
      end
    end

    errors
  end

  def build_royalty_from_row(row, import)
    # Find or create associated entities
    batch = find_or_create_batch(row)
    work = find_or_create_work(row)
    right_type = find_or_create_right_type(row)
    territory = find_or_create_territory(row)
    exploitation = find_or_create_exploitation(row)

    # Parse and create writers
    parse_and_create_writers(row["WRITERS"], work) if row["WRITERS"].present?

    # Build royalty with all mapped fields
    Royalty.new(
      import: import,
      batch: batch,
      work: work,
      right_type: right_type,
      territory: territory,
      exploitation: exploitation,
      agreement_code: row["AGREEMENT_ID"],
      custom_work_id: row["CUSTOM_WORK_ID"],
      distributed_amount: parse_decimal(row["DISTRIBUTED_AMOUNT"]),
      percentage_paid: parse_decimal(row["PERCENTAGE_PAID"]),
      unit_sum: parse_decimal(row["UNIT_SUM"]),
      wht_adj_received_amount: parse_decimal(row["WHT_ADJ_RECEIVED_AMOUNT"]),
      wht_adj_source_amount: parse_decimal(row["WHT_ADJ_SOURCE_AMOUNT"]),
      direct_collect_fee_taken: parse_decimal(row["DIRECT_COLLECT_FEE_TAKEN"]),
      direct_collected_amount: parse_decimal(row["DIRECT_COLLECTED_AMOUNT"]),
      credit_or_debit: row["CREDIT_OR_DEBIT"],
      recording_artist: row["RECORDING_ARTIST"],
      av_production_title: row["AV_PRODUCTION_TITLE"],
      period_start: parse_date(row["ROYALTY_PERIOD_START_DATE"]),
      period_end: parse_date(row["ROYALTY_PERIOD_END_DATE"]),
      source_name: row["SOURCE_NAME"],
      revenue_source_name: row["REVENUE_SOURCE_NAME"],
      generated_at_cover_rate: row["GENERATED_AT_COVER_RATE"]
    )
  end

  def find_or_create_batch(row)
    Batch.find_or_create_by!(code: row["BATCH_ID"]) do |batch|
      batch.description = row["BATCH_DESCRIPTION"]
    end
  end

  def find_or_create_work(row)
    Work.find_or_create_by!(work_id: row["WORK_ID"]) do |work|
      work.title = row["WORK_TITLE"]
    end
  end

  def find_or_create_right_type(row)
    RightType.find_or_create_by!(
      name: row["RIGHT_TYPE"],
      group: row["RIGHT_TYPE_GROUP"]
    )
  end

  def find_or_create_territory(row)
    Territory.find_or_create_by!(name: row["TERRITORY"]) do |territory|
      territory.iso_code = row["TERRITORY_ISO_ALPHA_2_CODE"]
    end
  end

  def find_or_create_exploitation(row)
    # Only create exploitation if at least one field is present
    licence_id = row["EXPLOITATION_LICENCE_ID"]
    title = row["EXPLOITATION_TITLE"]
    artist = row["EXPLOITATION_ARTIST"]
    description = row["EXPLOITATION_DESCRIPTION"]
    format = row["EXPLOITATION_FORMAT"]

    return nil if [ licence_id, title, artist, description, format ].all?(&:blank?)

    Exploitation.find_or_create_by!(
      licence_id: licence_id.presence,
      title: title.presence,
      artist: artist.presence
    ) do |exploitation|
      exploitation.description = description
      exploitation.format = format
    end
  end

  def parse_and_create_writers(writers_string, work)
    # Parse "Last, First [IP_CODE]" format
    # Can have multiple writers separated by semicolons or pipes
    writers_string.split(/[;|]/).each do |writer_str|
      writer_str = writer_str.strip
      next if writer_str.blank?

      if writer_str =~ /(.+?),\s*(.+?)\s*\[([^\]]+)\]/
        last_name = $1.strip
        first_name = $2.strip
        ip_code = $3.strip

        writer = Writer.find_or_create_by!(ip_code: ip_code) do |w|
          w.first_name = first_name
          w.last_name = last_name
        end

        # Create work-writer association if it doesn't exist
        WorkWriter.find_or_create_by!(work: work, writer: writer)
      end
    end
  end

  def parse_decimal(value)
    return nil if value.blank?
    BigDecimal(value)
  rescue ArgumentError
    nil
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value)
  rescue Date::Error
    nil
  end
end
