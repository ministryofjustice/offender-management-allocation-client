# frozen_string_literal: true

require 'rake'

namespace :trigger do
  desc 'Send an event if early allocation changed OOB (due to e.g. time passing)'
  task early_allocation_events: :environment do
    Offender.find_each do |offender|
      EarlyAllocationEventJob.perform_later(offender.nomis_offender_id)
    end
  end
end
