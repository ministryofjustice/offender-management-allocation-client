# frozen_string_literal: true

require 'base64'

module HmppsApi
  module Oauth
    class Token
      include Deserialisable

      attr_writer :expires_in,
                  :internal_user,
                  :token_type,
                  :auth_source,
                  :jti

      attr_accessor :access_token,
                    :scope

      def initialize(fields = {})
        # Allow this object to be reconstituted from a hash, we can't use
        # from_json as the one passed in will already be using the snake case
        # names whereas from_json is expecting the elite2 camelcase names.
        fields.each do |k, v| instance_variable_set("@#{k}", v) end

        @expiry_time = Time.zone.now + @expires_in.to_i.seconds
      end

      def needs_refresh?
        # we need to refresh the token just before expiry as it might expire on its way to the API
        @expiry_time - Time.zone.now < 20
      end

      def valid_token_with_scope?(scope)
        return false if payload['scope'].nil?
        return false unless payload['scope'].include? scope

        true
      rescue JWT::DecodeError, JWT::ExpiredSignature => e
        Sentry.capture_exception(e)
        false
      end

      def payload
        @payload ||= JWT.decode(
          access_token,
          OpenSSL::PKey::RSA.new(public_key),
          true,
          algorithm: 'RS256'
        ).first
      end

      def self.from_json(payload)
        Token.new(payload)
      end

    private

      def public_key
        @public_key ||= Base64.urlsafe_decode64(
          Rails.configuration.nomis_oauth_public_key
        )
      end
    end
  end
end
