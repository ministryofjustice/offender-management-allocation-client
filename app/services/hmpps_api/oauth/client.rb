# frozen_string_literal: true

module HmppsApi
  module Oauth
    class Client
      include ClientHelper

      def initialize(host)
        @host = host
        @connection = Faraday.new do |faraday|
          faraday.response :raise_error
        end
      end

      def post(route)
        request(:post, route)
      end

    private

      def request(method, route)
        response = @connection.send(method) { |req|
          url = URI.join(@host, route).to_s
          req.url(url)
          req.headers['Authorization'] = authorisation
        }

        JSON.parse(response.body)
      end
    end
  end
end
