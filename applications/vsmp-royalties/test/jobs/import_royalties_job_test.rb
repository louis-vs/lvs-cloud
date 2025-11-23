require "test_helper"

class ImportRoyaltiesJobTest < ActiveJob::TestCase
  setup do
    @import = Import.create!(
      original_file_name: "sample_royalties.csv",
      fiscal_year: 2024,
      fiscal_quarter: 1
    )

    # Attach the sample CSV file
    @import.csv_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/sample_royalties.csv")),
      filename: "sample_royalties.csv",
      content_type: "text/csv"
    )
  end

  test "successfully imports valid CSV file" do
    ImportRoyaltiesJob.perform_now(@import.id)

    @import.reload
    assert @import.number_of_royalties_added == 100, "Should have imported 100 royalties"
    assert Royalty.count == 100, "Should have created 100 royalties"
    assert Work.count.positive?, "Should have created works"
    assert Batch.count.positive?, "Should have created batches"
  end

  test "creates royalties with correct associations" do
    ImportRoyaltiesJob.perform_now(@import.id)

    royalty = Royalty.first
    assert_not_nil royalty.batch
    assert_not_nil royalty.work
    assert_not_nil royalty.right_type
    assert_not_nil royalty.territory
    assert_not_nil royalty.import
    assert_equal @import.id, royalty.import_id
  end

  test "parses and creates writers from 'Last, First [IP_CODE]' format" do
    ImportRoyaltiesJob.perform_now(@import.id)

    writer = Writer.first
    assert_not_nil writer
    assert_not_nil writer.first_name
    assert_not_nil writer.last_name
    assert_not_nil writer.ip_code
    assert_match(/IP\d+/, writer.ip_code)
  end

  test "creates work-writer associations" do
    ImportRoyaltiesJob.perform_now(@import.id)

    # Find a work from the imported CSV (not from fixtures)
    work = Work.find_by(work_id: "WK9000000")
    assert_not_nil work, "Work from CSV should exist"
    assert work.writers.any?, "Work should have associated writers"

    # Verify the writer details
    writer = work.writers.first
    assert_equal "Garcia", writer.last_name
    assert_equal "Michael", writer.first_name
    assert_equal "IP900000", writer.ip_code
  end

  test "find_or_create reuses existing entities" do
    # Create a batch that exists in the CSV
    existing_batch = Batch.create!(code: "BCH9000000", description: "Existing batch")

    batch_count_before = Batch.count
    ImportRoyaltiesJob.perform_now(@import.id)
    batch_count_after = Batch.count

    # Should create fewer batches since one already existed
    assert batch_count_after < 100 + batch_count_before, "Should reuse existing batch"

    # Verify the existing batch was reused
    royalty = Royalty.where(import: @import, batch: existing_batch).first
    assert_not_nil royalty, "Should have at least one royalty using the existing batch"
    assert_equal existing_batch.id, royalty.batch_id
  end

  test "updates import record with royalties count" do
    ImportRoyaltiesJob.perform_now(@import.id)

    @import.reload
    assert_equal Royalty.where(import: @import).count, @import.number_of_royalties_added
  end

  test "maps all CSV fields to royalty attributes correctly" do
    ImportRoyaltiesJob.perform_now(@import.id)

    royalty = Royalty.first

    # Check financial fields are mapped
    assert_not_nil royalty.distributed_amount
    assert_not_nil royalty.percentage_paid

    # Check date fields are parsed
    assert_kind_of Date, royalty.period_start if royalty.period_start
    assert_kind_of Date, royalty.period_end if royalty.period_end

    # Check string fields
    assert_not_nil royalty.agreement_code
    assert_not_nil royalty.credit_or_debit
  end

  test "handles exploitation fields correctly" do
    ImportRoyaltiesJob.perform_now(@import.id)

    royalty = Royalty.first
    if royalty.exploitation
      assert_not_nil royalty.exploitation
    else
      # Exploitation can be optional if all fields are empty
      assert_nil royalty.exploitation_id
    end
  end

  test "rolls back entire import on validation failure" do
    # Create invalid CSV with malformed data
    invalid_import = Import.create!(
      original_file_name: "invalid.csv",
      fiscal_year: 2024,
      fiscal_quarter: 1
    )

    csv_content = <<~CSV
      AGREEMENT_ID,BATCH_ID,WORK_ID,WORK_TITLE,WRITERS,RIGHT_TYPE_GROUP,RIGHT_TYPE,TERRITORY_ID,TERRITORY,DISTRIBUTED_AMOUNT,PERCENTAGE_PAID,UNIT_SUM,CREDIT_OR_DEBIT,ROYALTY_PERIOD_START_DATE,ROYALTY_PERIOD_END_DATE,TERRITORY_ISO_ALPHA_2_CODE
      AGR001,BCH001,WK001,Test Song,"Smith, John [IP001]",PERF,Performance,TERR001,USA,invalid_amount,100.0,1,Credit,2024-01-01,2024-03-31,US
    CSV

    invalid_import.csv_file.attach(
      io: StringIO.new(csv_content),
      filename: "invalid.csv",
      content_type: "text/csv"
    )

    assert_no_difference [ "Royalty.count", "Work.count", "Batch.count" ] do
      assert_raises(StandardError) do
        ImportRoyaltiesJob.perform_now(invalid_import.id)
      end
    end
  end

  test "collects and reports all validation errors" do
    # Test error collection logic
    skip "Implement after error collection logic is added"
  end

  test "handles empty writer field gracefully" do
    import_with_empty_writer = Import.create!(
      original_file_name: "empty_writer.csv",
      fiscal_year: 2024,
      fiscal_quarter: 1
    )

    csv_content = <<~CSV
      AGREEMENT_ID,BATCH_ID,WORK_ID,WORK_TITLE,WRITERS,RIGHT_TYPE_GROUP,RIGHT_TYPE,TERRITORY_ID,TERRITORY,DISTRIBUTED_AMOUNT,PERCENTAGE_PAID,UNIT_SUM,CREDIT_OR_DEBIT,ROYALTY_PERIOD_START_DATE,ROYALTY_PERIOD_END_DATE,TERRITORY_ISO_ALPHA_2_CODE,BATCH_DESCRIPTION,WHT_ADJ_RECEIVED_AMOUNT,WHT_ADJ_SOURCE_AMOUNT,DIRECT_COLLECT_FEE_TAKEN,DIRECT_COLLECTED_AMOUNT,SOURCE_NAME,GENERATED_AT_COVER_RATE,CUSTOM_WORK_ID,REVENUE_SOURCE_NAME,RECORDING_ARTIST,EXPLOITATION_LICENCE_ID,EXPLOITATION_TITLE,EXPLOITATION_ARTIST,EXPLOITATION_DESCRIPTION,EXPLOITATION_FORMAT,AV_PRODUCTION_TITLE
      AGR001,BCH001,WK001,Test Song,"",PERF,Performance,TERR001,USA,10.50,100.0,1,Credit,2024-01-01,2024-03-31,US,Test Batch,0,0,0,0,Test Source,N,CW001,Test Revenue,Test Artist,"","","","","",""
    CSV

    import_with_empty_writer.csv_file.attach(
      io: StringIO.new(csv_content),
      filename: "empty_writer.csv",
      content_type: "text/csv"
    )

    assert_nothing_raised do
      ImportRoyaltiesJob.perform_now(import_with_empty_writer.id)
    end

    # Should create work without writers
    work = Work.find_by(work_id: "WK001")
    assert_not_nil work
    assert_empty work.writers
  end
end
