#!/usr/bin/env ruby
require 'csv'
require 'securerandom'

# Generic names pool
FIRST_NAMES = %w[John Jane Mike Sarah Tom Lisa David Emma Chris Maria Robert Linda James Nancy Michael Barbara]
LAST_NAMES = %w[Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez Anderson Taylor Thomas Moore]

# Obfuscation mappings
writer_mapping = {}
work_mapping = {}
agreement_mapping = {}
batch_mapping = {}

def obfuscate_writer(writer_str, mapping)
  return "" if writer_str.nil? || writer_str.empty?

  # Parse "Last, First [IP_CODE]" format
  if writer_str =~ /(.+?),\s*(.+?)\s*\[([^\]]+)\]/
    original = writer_str
    return mapping[original] if mapping[original]

    # Generate new obfuscated writer
    first = FIRST_NAMES.sample
    last = LAST_NAMES.sample
    ip_num = 900000 + mapping.size
    obfuscated = "#{last}, #{first} [IP#{ip_num}]"
    mapping[original] = obfuscated
    obfuscated
  else
    writer_str
  end
end

def obfuscate_work_id(work_id, mapping)
  return mapping[work_id] if mapping[work_id]
  mapping[work_id] = "WK#{9000000 + mapping.size}"
  mapping[work_id]
end

def obfuscate_agreement_id(agr_id, mapping)
  return mapping[agr_id] if mapping[agr_id]
  mapping[agr_id] = "AGR#{9000 + mapping.size}"
  mapping[agr_id]
end

def obfuscate_batch_id(batch_id, mapping)
  return mapping[batch_id] if mapping[batch_id]
  mapping[batch_id] = "BCH#{9000000 + mapping.size}"
  mapping[batch_id]
end

def obfuscate_work_title(title)
  # Generic titles
  titles = [ "Untitled Track", "Song #{rand(1..999)}", "Composition #{rand(1..999)}",
            "Piece #{rand(1..999)}", "Track #{rand(1..999)}" ]
  titles.sample
end

# Read CSV
input_file = File.join(__dir__, 'master.csv')
output_file = File.join(__dir__, 'test', 'fixtures', 'files', 'sample_royalties.csv')

puts "Reading #{input_file}..."
csv_data = CSV.read(input_file, headers: true)

# Sample 100 random rows
puts "Sampling 100 random rows from #{csv_data.size} total rows..."
sampled_indices = (0...csv_data.size).to_a.sample(100).sort
sampled_rows = sampled_indices.map { |i| csv_data[i] }

# Create output directory if needed
require 'fileutils'
FileUtils.mkdir_p(File.dirname(output_file))

# Write obfuscated CSV
puts "Obfuscating and writing to #{output_file}..."
CSV.open(output_file, 'w', write_headers: true, headers: csv_data.headers) do |csv|
  sampled_rows.each do |row|
    # Obfuscate PII fields
    obfuscated_row = row.to_h.dup
    obfuscated_row['AGREEMENT_ID'] = obfuscate_agreement_id(row['AGREEMENT_ID'], agreement_mapping)
    obfuscated_row['BATCH_ID'] = obfuscate_batch_id(row['BATCH_ID'], batch_mapping)
    obfuscated_row['WORK_ID'] = obfuscate_work_id(row['WORK_ID'], work_mapping)
    obfuscated_row['WORK_TITLE'] = obfuscate_work_title(row['WORK_TITLE'])
    obfuscated_row['WRITERS'] = obfuscate_writer(row['WRITERS'], writer_mapping)
    obfuscated_row['CUSTOM_WORK_ID'] = row['CUSTOM_WORK_ID'].to_s.empty? ? "" : "CW#{9000 + rand(1000)}"

    csv << obfuscated_row.values
  end
end

puts "✅ Done! Generated #{output_file} with 100 obfuscated rows"
puts "   - #{writer_mapping.size} unique writers obfuscated"
puts "   - #{work_mapping.size} unique works obfuscated"
puts "   - #{agreement_mapping.size} unique agreements obfuscated"
puts "   - #{batch_mapping.size} unique batches obfuscated"
