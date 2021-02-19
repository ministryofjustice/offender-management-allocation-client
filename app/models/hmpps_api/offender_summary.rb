# frozen_string_literal: true

module HmppsApi
  class OffenderSummary < OffenderBase
    include Deserialisable

    attr_accessor :latest_movement

    attr_accessor :allocation_date

    attr_reader :prison_id, :facial_image_id

    def awaiting_allocation_for
      (Time.zone.today - prison_arrival_date).to_i
    end

    def case_owner
      if pom_responsibility.responsible?
        'Custody'
      else
        'Community'
      end
    end

    def self.from_json(payload)
      OffenderSummary.new.tap { |obj|
        obj.load_from_json(payload)
      }
    end

    # This list must only contain values that are returned by
    # https://api-dev.prison.service.justice.gov.uk/swagger-ui.html#//locations/getOffendersAtLocationDescription
    def load_from_json(payload)
      @booking_id = payload.fetch('bookingId').to_i
      @prison_id = payload.fetch('agencyId')
      @facial_image_id = payload['facialImageId']&.to_i

      super(payload)
    end
  end
end
