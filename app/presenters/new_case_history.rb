# frozen_string_literal: true

class NewCaseHistory
  delegate :allocated_at_tier, :pom_staff_id,
           :recommended_pom_type, :override_reasons, :override_detail, :suitability_detail,
           to: :@metadata

  def initialize(offender_event)
    @event = offender_event
    @metadata = OpenStruct.new(offender_event.metadata)
  end

  def created_at
    @event.happened_at
  end

  def created_by_name
    "#{@metadata.homd_first_name} #{@metadata.homd_last_name}"
  end

  def pom_name
    "#{@metadata.pom_first_name} #{@metadata.pom_last_name}"
  end

  def prison
    'LEI' # this is a hardcoded lie
  end

  # render a different partial depending on the type of event
  def to_partial_path
    "case_history/new_allocation/#{@event.event}"
  end
end
