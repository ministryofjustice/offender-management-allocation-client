# frozen_string_literal: true

namespace :cronjob do
  desc 'send monthly handover emails'
  task handover_email: :environment do |_task|
    LocalDeliveryUnit.enabled.each do |ldu|
      AutomaticHandoverEmailJob.perform_later(ldu)
    end
  end
end
