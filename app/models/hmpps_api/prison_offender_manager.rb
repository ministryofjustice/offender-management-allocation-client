# frozen_string_literal: true

module HmppsApi
  class PrisonOffenderManager
    include Deserialisable

    attr_reader :staff_id, :first_name, :last_name, :position,
                :agency_id, :position_description

    attr_accessor :status, :working_pattern

    def initialize(payload)
      @staff_id = payload['staffId'].to_i
      @first_name = payload['firstName']
      @last_name = payload['lastName']
      @agency_id = payload['agencyId']
      @position = payload['position']
      @position_description = payload['positionDescription']
    end

    def prison_officer?
      @position == RecommendationService::PRISON_POM
    end

    def probation_officer?
      @position == RecommendationService::PROBATION_POM
    end

    def full_name
      "#{last_name}, #{first_name}".titleize
    end

    def self.from_json(payload)
      PrisonOffenderManager.new(payload)
    end
  end
end
