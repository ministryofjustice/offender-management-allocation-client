# frozen_string_literal: true

module HmppsApi
  module PrisonApi
    class UserApi
      extend PrisonApiClient

      def self.user_details(username)
        route = "/users/#{username}"
        response = client.get(route)

        HmppsApi::UserDetails.from_json(response).tap do |user|
          user.email_address =
            HmppsApi::PrisonApi::PrisonOffenderManagerApi.fetch_email_addresses(user.staff_id)
        end
      end

      def self.user_caseloads(staff_id)
        route = "/staff/#{staff_id}/caseloads"
        response = client.get(route)

        response
      end
    end
  end
end
