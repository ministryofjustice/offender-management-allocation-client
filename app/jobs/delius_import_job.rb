require 'delius/emails'
require 'delius/processor'
require 'open3'

class DeliusImportJob < ApplicationJob
  queue_as :default

  FIELDS = [
      :crn, :pnc_no, :noms_no, :fullname, :tier, :roh_cds,
      :offender_manager, :org_private_ind, :org,
      :provider, :provider_code,
      :ldu, :ldu_code,
      :team, :team_code,
      :mappa, :mappa_levels, :date_of_birth
    ].freeze

  def perform
    username = ENV['DELIUS_EMAIL_USERNAME']
    password = ENV['DELIUS_EMAIL_PASSWORD']
    folder = ENV['DELIUS_EMAIL_FOLDER']

    Delius::Emails.connect(username, password) { |emails|
      emails.folder = folder

      attachment = emails.latest_attachment

      if attachment.present?
        process_attachment(attachment.body.decoded)
      else
        Rails.logger.error('Unable to find an attachment')
      end
    }
  end

private

  # rubocop:disable Metrics/MethodLength
  def process_attachment(contents)
    Dir.mktmpdir do |directory|
      zipfile = File.join(directory, 'encrypted.zip')
      File.open(zipfile, 'wb') do |file|
        file.write(contents)
      end
      zipcontents = Zip::File.open(zipfile).entries.first.get_input_stream
      encrypted_xlsx = File.join(directory, 'decrypted_attachment')
      File.open(encrypted_xlsx, 'wb') do |file|
        file.write(zipcontents.read)
      end

      filename = File.join(directory, 'decrypted_attachment')
      password = ENV['DELIUS_XLSX_PASSWORD']
      std_output, _status = Open3.capture2(
        'msoffice-crypt', '-d', '-p', password, encrypted_xlsx, filename
      )
      lines = std_output.split("\n")
      if lines.count > 1
        lines.each do |line| logger.error(line) end

        raise lines.last
      end

      process_decrypted_file(filename)
    end
  end
  # rubocop:enable Metrics/MethodLength

  def process_decrypted_file(filename)
    total = 0
    processor = Delius::Processor.new(filename)
    processor.run { |row|
      record = {}

      row.each_with_index do |val, idx|
        key = FIELDS[idx]
        record[key] = val
      end

      if record[:noms_no].present?
        DeliusDataService.upsert(record)
        total += 1
      end
    }
  end
end
