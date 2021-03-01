# frozen_string_literal: true

module HmppsApi
  module PrisonApi
    class OffenderApi
      extend PrisonApiClient

      def self.list(prison, page = 0, page_size: 20)
        route = "/locations/description/#{prison}/inmates"

        queryparams = { 'convictedStatus' => 'Convicted', 'returnCategory' => true }

        page_offset = page * page_size
        hdrs = paging_headers(page_size, page_offset)

        total_pages = nil
        data = client.get(
          route, queryparams: queryparams, extra_headers: hdrs
        ) { |_json, response|
          # Get the 'Total-Records' response header to calculate how many pages there are
          total_records = response.headers['Total-Records'].to_i
          total_pages = (total_records / page_size.to_f).ceil
        }

        recall_data = get_recall_flags(data.map { |o| o.fetch('offenderNo') })
        data.each do |offender|
          offender.merge!(recall_data.fetch(offender.fetch('offenderNo')))
        end

        offenders = data.map { |d| HmppsApi::OffenderSummary.from_json(d) }
        ApiPaginatedResponse.new(total_pages, offenders)
      end

      def self.get_offender(offender_no)
        # Bad NOMIS numbers mustn't produce invalid URLs
        url_offender_no = URI.encode_www_form_component(offender_no)
        route = "/prisoners/#{url_offender_no}"
        response = client.get(route)

        if response.empty?
          nil
        else
          recall_data = get_recall_flags([url_offender_no])
          HmppsApi::Offender.from_json(response.first.merge(recall_data.fetch(url_offender_no))).tap do |offender|
            sentence_details = get_bulk_sentence_details([offender.booking_id])
            offender.sentence = sentence_details.fetch(offender.booking_id)
            add_arrival_dates([offender])
          end
        end
      end

      def self.get_offence(booking_id)
        route = "/bookings/#{booking_id}/mainOffence"
        data = client.get(route)
        return '' if data.empty?

        data.first['offenceDescription']
      end

      def self.get_category_code(offender_no)
        route = '/offender-assessments/CATEGORY'
        data = client.post(route, [offender_no], cache: true)
        return '' if data.empty?

        data.first['classificationCode']
      end

      def self.get_bulk_sentence_details(booking_ids)
        return {} if booking_ids.empty?

        route = '/offender-sentences/bookings'
        data = client.post(route, booking_ids, cache: true)

        data.map do |record|
          [
              record.fetch('bookingId'),
              HmppsApi::SentenceDetail.from_json(record['sentenceDetail'])
          ]
        end.to_h
      end

      def self.get_image(booking_id)
        # This method returns the raw bytes of an image, the equivalent of loading the
        # image from file on disk.
        details_route = '/offender-sentences/bookings'
        details = client.post(details_route, [booking_id], cache: true)

        return default_image if details.first['facialImageId'].blank?

        image_route = "/images/#{details.first['facialImageId']}/data"
        image = client.raw_get(image_route)

        image.presence || default_image
      rescue Faraday::ResourceNotFound
        # It's possible that the offender does not yet have an image of their
        # face, and so when an image can't be found, we will return the default
        # image instead.
        default_image
      end

      def self.add_arrival_dates(offenders)
        movements = HmppsApi::PrisonApi::MovementApi.admissions_for(offenders.map(&:offender_no))

        offenders.each do |offender|
          arrival = movements.fetch(offender.offender_no, []).reverse.detect { |movement|
            movement.to_agency == offender.prison_id
          }
          offender.prison_arrival_date = [offender.sentence_start_date, arrival&.movement_date].compact.max
        end
      end

    private

      def self.get_recall_flags(offender_nos)
        search_route = '/prisoner-numbers'
        search_result = search_client.post(search_route, { prisonerNumbers: offender_nos }, cache: true)
                                     .index_by { |prisoner| prisoner.fetch('prisonerNumber') }
        offender_nos.index_with { |nomis_id| { 'recall' => search_result.fetch(nomis_id, {}).fetch('recall', false) } }
      end

      def self.paging_headers(page_size, page_offset)
        {
          'Page-Limit' => page_size.to_s,
          'Page-Offset' => page_offset.to_s
        }
      end

      def self.default_image
        File.read(Rails.root.join('app/assets/images/default_profile_image.jpg'))
      end
    end
  end
end
