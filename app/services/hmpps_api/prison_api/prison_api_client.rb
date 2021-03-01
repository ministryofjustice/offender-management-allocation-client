# frozen_string_literal: true

module HmppsApi
  module PrisonApi
    ApiPaginatedResponse = Struct.new(:total_pages, :data)

    module PrisonApiClient
      # Client for the Prison API
      def client
        host = Rails.configuration.prison_api_host
        HmppsApi::Client.new(host + '/api')
      end

      # Client for the Prisoner Offender Search API
      def search_client
        host = Rails.configuration.prisoner_search_host
        HmppsApi::Client.new(host + '/prisoner-search')
      end
    end
  end
end
