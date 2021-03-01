# frozen_string_literal: true

module HmppsApi
  class KeyworkerApi
    def self.get_keyworker(location, offender_no)
      route = "/key-worker/#{location}/offender/#{offender_no}"
      response = client.get(route)
      HmppsApi::KeyworkerDetails.from_json(response)
    rescue Faraday::ResourceNotFound # 404 Not Found error
      HmppsApi::NullKeyworker.new
    end

    def self.client
      host = Rails.configuration.keyworker_api_host
      HmppsApi::Client.new(host)
    end
  end
end
