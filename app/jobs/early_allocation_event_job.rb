class EarlyAllocationEventJob < ApplicationJob
  queue_as :default

  def perform offender_id
    offender = OffenderService.get_offender(offender_id)
    offender.trigger_early_allocation_event
  end
end
