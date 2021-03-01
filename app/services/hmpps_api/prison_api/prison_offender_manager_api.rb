# frozen_string_literal: true

module HmppsApi
  module PrisonApi
    class PrisonOffenderManagerApi
      extend PrisonApiClient

      def self.staff_detail(staff_id)
        route = "/staff/#{staff_id}"
        data = client.get(route)
        HmppsApi::StaffDetails.from_json(data)
      end

      def self.list(prison)
        route = "/staff/roles/#{prison}/role/POM"
        data = client.get(route, extra_headers: paging_options)
        data.map { |d| HmppsApi::PrisonOffenderManager.from_json(d) }
      end

      def self.fetch_email_addresses(nomis_staff_id)
        route = "/staff/#{nomis_staff_id}/emails"
        data = client.get(route)
        return [] if data.nil?

        data
      end

    private

      def self.paging_options
        {
          'Page-Limit' => '100',
          'Page-Offset' => '0'
        }
      end
    end
  end
end
