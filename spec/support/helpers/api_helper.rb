# frozen_string_literal: true

module ApiHelper
  AUTH_HOST = Rails.configuration.nomis_oauth_host
  T3 = "#{Rails.configuration.prison_api_host}/api"
  T3_SEARCH = "#{Rails.configuration.prisoner_search_host}/prisoner-search"
  KEYWORKER_API_HOST = ENV.fetch('KEYWORKER_API_HOST')
  COMMUNITY_HOST = "#{Rails.configuration.community_api_host}/secure"
  T3_LATEST_MOVE_URL = "#{T3}/movements/offenders?latestOnly=true&movementTypes=TAP"
  T3_BOOKINGS_URL = "#{T3}/offender-sentences/bookings"

  def stub_offender(offender)
    booking_number = offender.fetch(:bookingId)
    offender_no = offender.fetch(:offenderNo)
    stub_request(:get, "#{T3}/prisoners/#{offender_no}").
      to_return(body: [
        offender.except(:sentence, :recall, :agencyId).merge(
          'latestBookingId' => booking_number,
          'latestLocationId' => offender.fetch(:agencyId))
      ].to_json)

    stub_request(:post, "#{T3_SEARCH}/prisoner-numbers").with(body: { prisonerNumbers: [offender_no] }).
      to_return(body: [
        {
          prisonerNumber: offender_no,
          recall: offender.fetch(:recall),
          imprisonmentStatus: offender.fetch(:sentence).fetch(:imprisonmentStatus),
          indeterminateSentence: offender.fetch(:sentence).fetch(:indeterminateSentence),
          imprisonmentStatusDescription: offender.fetch(:sentence).fetch(:imprisonmentStatusDescription),
          cellLocation: offender.fetch(:internalLocation)
        }
      ].to_json)

    stub_request(:post, "#{T3}/offender-sentences/bookings").
      with(
        body: [booking_number].to_json
      ).
      to_return(body: [
        {
          offenderNo: offender_no,
          bookingId: booking_number,
          sentenceDetail: offender.fetch(:sentence).reject { |_k, v| v.nil? }
        }].to_json)

    stub_offender_categories([offender])

    stub_request(:get, "#{T3}/bookings/#{booking_number}/mainOffence").
      to_return(body: {}.to_json)

    stub_movements

    stub_request(:post, T3_LATEST_MOVE_URL).with(
      body: [offender_no].to_json).
      to_return(body: [].to_json)

    stub_request(:get, "#{Rails.configuration.complexity_api_host}/v1/complexity-of-need/offender-no/#{offender_no}").
      to_return(body: { level: offender.fetch(:complexityLevel) }.to_json)
  end

  def stub_movements(movements = [])
    stub_request(:post, "#{T3}/movements/offenders?movementTypes=ADM&movementTypes=TRN&latestOnly=false").
      to_return(body: movements.to_json)
    stub_request(:post, "#{T3}/movements/offenders?movementTypes=REL&latestOnly=false").
      to_return(body: movements.to_json)
  end

  def stub_movements_for offender_no, movements, movement_types: ['ADM', 'TRN']
    stub_request(:post, "#{T3}/movements/offenders?#{movement_types.map { |t| "movementTypes=#{t}" }.join('&')}&latestOnly=false&allBookings=true").
      with(body: [offender_no].to_json).
      to_return(body: movements.to_json)
  end

  def stub_poms(prison, poms)
    poms.each { |pom| pom.agencyId = prison }

    stub_request(:get, "#{T3}/staff/roles/#{prison}/role/POM").
      with(
        headers: {
          'Page-Limit' => '100',
          'Page-Offset' => '0'
        }).
      to_return(body: poms.to_json)
    poms.each do |pom|
      stub_pom(pom)
      stub_pom_emails(pom.staffId, pom.emails)
    end
  end

  def stub_pom_emails(staff_id, emails)
    stub_request(:get, "#{T3}/staff/#{staff_id}/emails").
      to_return(body: emails.to_json)
  end

  def stub_pom(pom)
    stub_request(:get, "#{T3}/staff/#{pom.staffId}").
      to_return(body: pom.to_json)
  end

  def stub_signed_in_pom(prison, staff_id, username = 'alice')
    stub_auth_token
    stub_sso_data(prison, username: username, roles: [SsoIdentity::POM_ROLE])
    stub_request(:get, "#{T3}/users/#{username}").
      to_return(body: { 'staffId': staff_id }.to_json)
  end

  def stub_signed_in_spo_pom(prison, staff_id, username = 'alice')
    stub_auth_token
    stub_sso_data(prison, username: username, roles: [SsoIdentity::POM_ROLE, SsoIdentity::SPO_ROLE])
    stub_request(:get, "#{T3}/users/#{username}").
        to_return(body: { 'staffId': staff_id }.to_json)
  end

  def stub_offenders_for_prison(prison, offenders, movements = [])
    # Stub the call to get_offenders_for_prison. Takes a list of offender hashes (in nomis camelCase format) and
    # a list of bookings (same key format). It it your responsibility to make sure they contain the data you want
    # and if you provide a booking, that the id matches between the offender and booking hashes.
    elite2listapi = "#{T3}/locations/description/#{prison}/inmates?convictedStatus=Convicted"

    # Stub the call that will get the total number of records
    stub_request(:get, elite2listapi).to_return(
      body: {}.to_json,
      headers: { 'Total-Records' => offenders.count.to_s }
    )

    # make up a set of booking ids
    booking_ids = 1.upto(offenders.size)

    # Return the actual offenders from the call to /locations/description/PRISON/inmates
    stub_request(:get, elite2listapi).with(
      headers: {
        'Page-Limit' => '200',
        'Page-Offset' => '0'
      }).to_return(body: offenders.zip(booking_ids)
                           .map { |o, booking_id|
                           o.except(:sentence, :recall, :agencyId)
                                                    .merge('bookingId' => booking_id,
                                                           'agencyId' => prison,
                                                           'assignedLivingUnitDesc' => o[:internalLocation])
                         }                         .to_json)

    offender_nos = offenders.map { |offender| offender.fetch(:offenderNo) }
    stub_request(:post, "#{T3_SEARCH}/prisoner-numbers").
      with(body: { prisonerNumbers: offender_nos }.to_json).
      to_return(body: offenders.map { |offender|
                        {
                          prisonerNumber: offender.fetch(:offenderNo),
                          recall: offender.fetch(:recall),
                          imprisonmentStatus: offender.fetch(:sentence).fetch(:imprisonmentStatus),
                          indeterminateSentence: offender.fetch(:sentence).fetch(:indeterminateSentence),
                          imprisonmentStatusDescription: offender.fetch(:sentence).fetch(:imprisonmentStatusDescription),
                          cellLocation: offender.fetch(:internalLocation)
                        }
                      }.to_json)

    bookings = booking_ids.zip(offenders).map do |booking_id, offender|
      {
          'bookingId' => booking_id,
          'sentenceDetail' => offender.fetch(:sentence).reject { |_k, v| v.nil? }
      }
    end

    stub_request(:post, T3_BOOKINGS_URL).with(body: booking_ids.to_json).
      to_return(body: bookings.to_json)

    stub_request(:post, T3_LATEST_MOVE_URL).with(
      body: offender_nos.to_json).
      to_return(body: movements.to_json)

    stub_offender_categories(offenders)

    stub_movements

    allow(HmppsApi::ComplexityApi).to receive(:get_complexities).with(offender_nos).and_return(
      offenders.map { |offender| [offender.fetch(:offenderNo), offender.fetch(:complexityLevel)] }.to_h
    )

    offenders.each { |o| stub_offender(o) }
  end

  def stub_multiple_offenders(offenders, bookings)
    stub_request(:post, "#{T3}/prisoners").to_return(
      body: offenders.to_json
    )

    stub_request(:post, T3_BOOKINGS_URL).
      to_return(body: bookings.to_json)
  end

  def stub_offender_categories(offenders)
    offender_nos = offenders.map { |offender| offender.fetch(:offenderNo) }
    categories = offenders.reject { |offender| offender[:category].nil? }
                   .map { |offender| offender.fetch(:category).merge(offenderNo: offender.fetch(:offenderNo)) }

    stub_request(:post, "#{T3}/offender-assessments/CATEGORY?activeOnly=true&latestOnly=true&mostRecentOnly=true").
      with(
        body: offender_nos.to_json
      ).
      to_return(body: categories.to_json)
  end

  # Stub an 'empty' response from the Prison API, indicating that the offender does not exist in NOMIS
  # Note: you might have expected a 404 Not Found response when the offender doesn't exist, but
  #       the actual response is 200 OK with an empty JSON array.
  #       This stub is faithful to the Prison API docs and real-world behaviour.
  def stub_non_existent_offender(offender_no)
    stub_request(:get, "#{T3}/prisoners/#{offender_no}").
      to_return(body: [].to_json)
  end

  def stub_keyworker(prison_code, offender_id, keyworker)
    stub_request(:get, "#{KEYWORKER_API_HOST}/key-worker/#{prison_code}/offender/#{offender_id}").
      to_return(body: keyworker.to_json)
  end

  def reload_page
    visit current_path
  end

  def stub_community_offender(nomis_offender_id, community_data, registrations = [])
    stub_request(:get, "#{COMMUNITY_HOST}/offenders/nomsNumber/#{nomis_offender_id}/all").
        to_return(body: community_data.to_json)
    stub_request(:get, "#{COMMUNITY_HOST}/offenders/nomsNumber/#{nomis_offender_id}/registrations").
        to_return(body: { registrations: registrations }.to_json)
    stub_request(:get, "#{COMMUNITY_HOST}/offenders/nomsNumber/#{nomis_offender_id}/risk/resourcing/latest").
        to_return(body: { enhancedResourcing: community_data.fetch(:enhancedResourcing) }.to_json)
  end

  def stub_resourcing_404 nomis_offender_id
    stub_request(:get, "#{COMMUNITY_HOST}/offenders/nomsNumber/#{nomis_offender_id}/risk/resourcing/latest").
      to_return(status: 404)
  end
end
