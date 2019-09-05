# frozen_string_literal: true

require_relative '../allocation_validation'

namespace :fix_data do
  desc 'Fixes data for incorrect transfer/releases/allocations'
  task :for_prison, [:prison] => [:environment] do |_task, args|
    prison = args[:prison]

    if PrisonService.name_for(prison).nil?
      puts "Unable to find prison #{prison}"
      next
    end

    AllocationValidation.new.fixup(prison)
  end
end
