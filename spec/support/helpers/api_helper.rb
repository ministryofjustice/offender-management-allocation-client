# frozen_string_literal: true

module ApiHelper
  T3_HOST = Rails.configuration.nomis_oauth_host
  T3 = "#{T3_HOST}/elite2api/api"
  KEYWORKER_API_HOST = ENV.fetch('KEYWORKER_API_HOST')

  def stub_offender(offender)
    booking_number = 1
    stub_request(:get, "#{T3}/prisoners/#{offender.fetch(:offenderNo)}").
      to_return(body: [{ offenderNo: offender.fetch(:offenderNo),
                                      gender: 'Male',
                                      convictedStatus: 'Convicted',
                                      latestBookingId: booking_number,
                                      imprisonmentStatus: offender.fetch(:imprisonmentStatus),
                                      dateOfBirth: offender.fetch(:dateOfBirth) }].to_json)

    stub_request(:post, "#{T3}/offender-sentences/bookings").
      with(
        body: [booking_number].to_json
      ).
      to_return(body: [{ offenderNo: offender.fetch(:offenderNo), bookingId: booking_number,
                                      sentenceDetail: offender.fetch(:sentence) }].to_json)

    stub_request(:post, "#{T3}/offender-assessments/CATEGORY").
      with(
        body: [offender.fetch(:offenderNo)].to_json
      ).
      to_return(body: {}.to_json)

    stub_request(:get, "#{T3}/bookings/#{booking_number}/mainOffence").
      to_return(body: {}.to_json)

    stub_sentence_type(booking_number)
  end

  def stub_movements(movements = [])
    stub_request(:post, "#{T3}/movements/offenders?movementTypes=ADM&movementTypes=TRN&latestOnly=false").
      to_return(body: movements.to_json)
  end

  def stub_poms(prison, poms)
    stub_request(:get, "#{T3}/staff/roles/#{prison}/role/POM").
      with(
        headers: {
          'Page-Limit' => '100',
          'Page-Offset' => '0'
        }).
      to_return(body: poms.to_json)
    poms.each do |pom|
      stub_pom_emails(pom.staffId, pom.emails)
    end
  end

  def stub_pom_emails(staff_id, emails)
    stub_request(:get, "#{T3}/staff/#{staff_id}/emails").
      to_return(body: emails.to_json)
  end

  def stub_signed_in_pom(prison, staff_id, username)
    stub_auth_token
    stub_sso_data(prison, username, 'ROLE_ALLOC_CASE_MGR')
    stub_request(:get, "#{T3}/users/#{username}").
      to_return(body: { 'staffId': staff_id }.to_json)
  end

  def stub_offenders_for_prison(prison, offenders)
    # Stub the call to get_offenders_for_prison. Takes a list of offender hashes (in nomis camelCase format) and
    # a list of bookings (same key format). It it your responsibility to make sure they contain the data you want
    # and if you provide a booking, that the id matches between the offender and booking hashes.
    elite2listapi = "#{T3}/locations/description/#{prison}/inmates?convictedStatus=Convicted&returnCategory=true"
    elite2bookingsapi = "#{T3}/offender-sentences/bookings"

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
      }).to_return(body: offenders.zip(booking_ids).map { |o, booking_id| o.except(:sentence).merge('bookingId' => booking_id, 'agencyId' => prison) }.to_json)

    bookings = booking_ids.zip(offenders).map { |booking_id, offender| { 'bookingId' => booking_id, 'sentenceDetail' => offender.fetch(:sentence) } }
    stub_request(:post, elite2bookingsapi).with(body: booking_ids.to_json).
      to_return(body: bookings.to_json)
  end

  def stub_multiple_offenders(offenders, bookings)
    elite2listapi = "#{T3}/prisoners"
    elite2bookingsapi = "#{T3}/offender-sentences/bookings"

    stub_request(:post, elite2listapi).to_return(
      body: offenders.to_json
    )

    stub_request(:post, elite2bookingsapi).
      to_return(body: bookings.to_json)
  end

  def stub_sentence_type(booking_id)
    stub_request(:get, "#{T3}/offender-sentences/booking/#{booking_id}/sentenceTerms").to_return(body: [].to_json)
  end

  def reload_page
    visit current_path
  end
end
