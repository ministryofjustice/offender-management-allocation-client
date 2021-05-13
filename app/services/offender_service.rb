# frozen_string_literal: true

class OffenderService
  class << self
    def get_offender(offender_no)
      # use find_or_create_by here for performance, but might still have be a small race condition
      # This isn't find_or_create_by! because our offender_no might be invalid - we want to return nil rather than crash
      offender = Offender.find_or_create_by(nomis_offender_id: offender_no)
      if offender
        api_offender = HmppsApi::PrisonApi::OffenderApi.get_offender(offender_no)
        if api_offender
          api_offender.load_main_offence
          prison = Prison.find_by(code: api_offender.prison_id)
          # ignore offenders in prisons that we don't know about
          MpcOffender.new prison: prison, offender: offender, prison_record: api_offender if prison
        end
      end
    end

    def get_offenders_for_prison(prison)
      OffenderEnumerator.new(prison)
    end

    class OffenderEnumerator
      include Enumerable
      FETCH_SIZE = 200 # How many records to fetch from nomis at a time

      def initialize(prison)
        @prison = prison
      end

      def each
        first_page = HmppsApi::PrisonApi::OffenderApi.list(@prison.code, 0, page_size: FETCH_SIZE)
        offenders = first_page.data
        enrich_offenders(offenders).each { |offender| yield offender }

        1.upto(first_page.total_pages - 1).each do |page_number|
          offenders = HmppsApi::PrisonApi::OffenderApi.list(
            @prison.code,
            page_number,
            page_size: FETCH_SIZE
          ).data

          enrich_offenders(offenders).each { |offender| yield offender }
        end
      end

      def enrich_offenders(offender_list)
        nomis_ids = offender_list.map(&:offender_no)
        offenders = Offender.
          includes(:early_allocations, :responsibility, case_information: [:local_delivery_unit]).
          where(nomis_offender_id: nomis_ids)

        if offenders.count != nomis_ids.count
          # Create Offender records for (presumably new) prisoners who don't have one yet
          nomis_ids.reject { |nomis_id| offenders.detect { |offender| offender.nomis_offender_id == nomis_id } }.each do |new_id|
            # use create_or_find_by! to prevent race conditions
            new_offender = Offender.create_or_find_by! nomis_offender_id: new_id
            offenders = offenders + [new_offender]
          end
        end

        HmppsApi::PrisonApi::OffenderApi.add_arrival_dates(offender_list)
        nomis_offenders_hash = offender_list.index_by(&:offender_no)
        offenders.map { |offender| MpcOffender.new(prison: @prison, offender: offender, prison_record: nomis_offenders_hash.fetch(offender.nomis_offender_id)) }
      end
    end

    def get_community_data(nomis_offender_id)
      community_info = HmppsApi::CommunityApi::get_offender(nomis_offender_id).deep_symbolize_keys
      mappa_registrations = HmppsApi::CommunityApi::get_offender_registrations(nomis_offender_id).deep_symbolize_keys
                              .fetch(:registrations, [])
                              .select { |r|
                                r.fetch(:active) && r.key?(:registerLevel) && r.dig(:registerLevel, :code).starts_with?('M')
                              }
      resourcing = begin
                   HmppsApi::CommunityApi.get_latest_resourcing(nomis_offender_id).deep_symbolize_keys
                   rescue Faraday::ResourceNotFound
                     { enhancedResourcing: true } # assume NPS when not found
                 end

      com = community_info.fetch(:offenderManagers).detect { |om| om.fetch(:active) }
      {
          noms_no: nomis_offender_id,
          tier: community_info.fetch(:currentTier),
          crn: community_info.dig(:otherIds, :crn),

          service_provider: resourcing.fetch(:enhancedResourcing) ? 'NPS' : 'CRC',
          offender_manager: com.dig(:staff, :unallocated) ? nil : "#{com.dig(:staff, :surname)}, #{com.dig(:staff, :forenames)}",
          team_name: com.dig(:team, :description),
          ldu_code: com.dig(:team, :localDeliveryUnit, :code),
          mappa_levels: mappa_registrations.map { |r| r.dig(:registerLevel, :code).last.to_i }
        }
    end
  end
end
