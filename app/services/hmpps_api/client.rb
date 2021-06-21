# frozen_string_literal: true

require 'faraday'
require 'typhoeus/adapters/faraday'

module HmppsApi
  class Client
    # Beyond 8 retries the backoff becomes e.g. 12 seconds at 10 retries
    MAX_RETRIES = 8
    def initialize(root)
      @root = root
      retry_options = {
          max: MAX_RETRIES,
          # some useful values as per the Faraday documentation
          # https://lostisland.github.io/faraday/middleware/retry
          # for some reason this middleware doesn't provide sensible defaults
          # but does have some good suggestions in the documentation
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2,
          # we seem to get 502 and 504 statuses from a gateway this side of
          # the Prison API - cso retry if we get one of those.
          retry_statuses: [502, 504],
          exceptions: Faraday::Request::Retry::DEFAULT_EXCEPTIONS + [Faraday::ConnectionFailed, Faraday::ServerError],
          # Faraday by default doesn't retry on a POST - even though our POSTs are GETs in disguise.
          methods: Faraday::Request::Retry::IDEMPOTENT_METHODS + [:post],
          #retry_if: ->(_env, _exception) { true },
          retry_block: ->(env, _options, retries_left, exception) {
            retries = MAX_RETRIES - retries_left
            # This is purely for debugging, and probably shouldn't make it to production
            puts("#{Time.zone.now} Retry ##{retries} for #{env.url} with status [#{env.status}] exception #{exception.inspect}")
            Rails.logger.warn("#{Time.zone.now} Retry ##{retries} for #{env.url} with status [#{env.status}] exception #{exception.inspect}")
          }
      }
      @connection = Faraday.new do |faraday|
        faraday.options.params_encoder = Faraday::FlatParamsEncoder

        # This is adding 2 pieces of request middleware and 1 piece of response middleware
        faraday.request :retry, retry_options
        faraday.request :instrumentation
        # Response middleware is supposed to be registered after request middleware
        faraday.response :raise_error
        faraday.adapter :typhoeus
      end
    end

    # Performs a basic GET request without processing the response. This is mostly
    # used for when we do not want a JSON response from an endpoint.
    def raw_get(route, queryparams: {}, extra_headers: {})
      response = request(
        :get, route, queryparams: queryparams, extra_headers: extra_headers
      )
      response.body
    end

    def get(route, queryparams: {}, extra_headers: {}, cache: true)
      response = request(
        :get, route, queryparams: queryparams, extra_headers: extra_headers, cache: cache
      )

      # Elite2 can return a 204 to mean empty results, and we don't know if
      # it is meant to be a {} or a []. For now, we are going to use nil and
      # let the caller handle it.
      data = if response.status == 204
               nil
             else
               JSON.parse(response.body)
             end

      if block_given?
        yield data, response
      end

      data
    end

    def post(route, body, queryparams: {}, extra_headers: {}, cache: false)
      response = request(
        :post, route, queryparams: queryparams, extra_headers: extra_headers, body: body, cache: cache
      )

      JSON.parse(response.body)
    end

    def put(route, body, queryparams: {}, extra_headers: {})
      response = request(
        :put, route, queryparams: queryparams, extra_headers: extra_headers, body: body
      )

      JSON.parse(response.body)
    end

    def delete(route, queryparams: {}, extra_headers: {})
      request(
        :delete, route, queryparams: queryparams, extra_headers: extra_headers
      )
    end

  private

    def request(method, route, queryparams: {}, extra_headers: {}, body: nil, cache: false)
      if cache
        # Cache the request
        key = cache_key(method, route, queryparams: queryparams, extra_headers: extra_headers, body: body)
        Rails.cache.fetch(key, expires_in: Rails.configuration.cache_expiry) do
          send_request(method, route, queryparams: queryparams, extra_headers: extra_headers, body: body)
        end
      else
        # Don't cache the request
        send_request(method, route, queryparams: queryparams, extra_headers: extra_headers, body: body)
      end
    end

    def send_request(method, route, queryparams:, extra_headers:, body:)
      @connection.send(method) do |req|
        req.url(@root + route)
        req.headers['Authorization'] = "Bearer #{token.access_token}"
        req.headers['Content-Type'] = 'application/json' unless body.nil?
        req.headers.merge!(extra_headers)
        req.params.update(queryparams)
        req.body = body.to_json unless body.nil?
      end
    end

    def cache_key(method, route, queryparams:, extra_headers:, body:)
      # An array of everything that makes this request unique
      request_parameters = [@root, method, route, queryparams, extra_headers, body]

      # Create a SHA256 hash which uniquely identifies this request
      fingerprint = Digest::SHA256.hexdigest(request_parameters.to_json)

      "hmpps_api_request_#{fingerprint}"
    end

    def token
      HmppsApi::Oauth::TokenService.valid_token
    end
  end
end
