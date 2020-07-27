require 'rails_helper'

context 'when NOMIS is missing information' do
  let(:prison_code) { 'LEI' }
  let(:offender_no) { 'A1' }
  let(:stub_auth_host) { Rails.configuration.nomis_oauth_host }
  let(:stub_api_host) { "#{stub_auth_host}/elite2api/api" }
  let(:stub_keyworker_host) { Rails.configuration.keyworker_api_host }
  let(:staff_id) { 111_111 }

  describe 'when logged in as a POM' do
    before do
      user_name = 'example_user'
      stub_poms = [{ staffId: staff_id, position: RecommendationService::PRISON_POM }]

      stub_request(:post, "#{stub_auth_host}/auth/oauth/token").
        with(query: { grant_type: 'client_credentials' }).
        to_return(status: 200, body: {}.to_json)

      stub_request(:get, "#{stub_api_host}/users/example_user").
        to_return(status: 200, body: { staffId: staff_id }.to_json)

      stub_request(:get, "#{stub_api_host}/staff/#{staff_id}/emails").
        to_return(status: 200, body: [].to_json)

      stub_request(:get, "#{stub_api_host}/staff/roles/#{prison_code}/role/POM").
        to_return(status: 200, body: stub_poms.to_json)

      signin_pom_user(user_name)
    end

    describe 'the caseload page' do
      context 'with an NPS offender with a determinate sentence, but no required release dates' do
        before do
          stub_offenders = [{
            offenderNo: offender_no,
            bookingId: 1,
            dateOfBirth: '1990-01-01',
            imprisonmentStatus: 'SEC91'
          }]

          stub_bookings = [{
            bookingId: 1,
            sentenceDetail: {
            releaseDate: 30.years.from_now.iso8601,
              sentenceStartDate: Time.zone.now.iso8601
            }
          }]

          stub_offenders_for_prison(prison_code, stub_offenders, stub_bookings)

          create(:allocation, nomis_offender_id: offender_no, primary_pom_nomis_id: staff_id)
          create(:case_information, nomis_offender_id: offender_no, case_allocation: 'NPS')
        end

        it 'does not error' do
          visit prison_caseload_index_path(prison_code)

          expect(page).to have_content('Your caseload (0)')
        end
      end
    end

    describe 'the prisoner page' do
      let(:booking_id) { 3 }

      before do
        stub_bookings = [{
          bookingId: booking_id,
          sentenceDetail: {
            releaseDate: 30.years.from_now.iso8601,
            sentenceStartDate: Time.zone.now.iso8601
          }
        }]

        stub_offender = [{
          offenderNo: offender_no,
          latestBookingId: booking_id,
          bookingId: booking_id
        }]

        stub_request(:get, "#{stub_api_host}/staff/#{staff_id}").
          to_return(status: 200, body: { staffId: staff_id, firstName: "TEST", lastName: "MOIC" }.to_json)

        stub_request(:get, "#{stub_api_host}/prisoners/#{offender_no}").
          to_return(status: 200, body: stub_offender.to_json)

        stub_request(:post, "#{stub_api_host}/offender-assessments/CATEGORY").
          to_return(status: 200, body: {}.to_json)

        stub_request(:get, "#{stub_api_host}/bookings/#{booking_id}/mainOffence").
          to_return(status: 200, body: {}.to_json)

        stub_request(:get, "#{stub_keyworker_host}/key-worker/#{prison_code}/offender/#{offender_no}").
          to_return(status: 200, body: {}.to_json)

        stub_offenders_for_prison(prison_code, stub_offender, stub_bookings)

        create(:allocation, nomis_offender_id: offender_no, primary_pom_nomis_id: staff_id)
        create(:case_information, nomis_offender_id: offender_no, case_allocation: 'NPS')
      end

      it 'does not error' do
        visit prison_prisoner_path(prison_code, offender_no)

        expect(page).to have_content('Prisoner information')

        earliest_release_date = find('#earliest_release_date').text
        expect(earliest_release_date).to eq('Unknown')
      end
    end

    describe 'the handover start page' do
      let(:booking_id) { 3 }

      before do
        stub_bookings = [{
          bookingId: booking_id,
          sentenceDetail: {
            releaseDate: 30.years.from_now.iso8601,
            sentenceStartDate: Time.zone.now.iso8601
          }
        }]

        stub_offenders = [{
          offenderNo: offender_no,
          latestBookingId: booking_id,
          bookingId: booking_id
        }]

        stub_offenders_for_prison(prison_code, stub_offenders, stub_bookings)
      end

      it 'does not error' do
        create(:allocation, nomis_offender_id: offender_no, primary_pom_nomis_id: staff_id)

        visit prison_caseload_handover_start_path(prison_code)

        expect(page).to have_content('All cases for start of handover to the community in the next 30 days')
      end
    end
  end

  context 'when logged in as an SPO' do
    before do
      stub_request(:post, "#{stub_auth_host}/auth/oauth/token").
        with(query: { grant_type: 'client_credentials' }).
        to_return(status: 200, body: {}.to_json)

      signin_spo_user('example SPO')
    end

    context 'with an NPS offender with an indeterminate sentence, but no release dates' do
      let(:booking_id) { 4 }

      before do
        stub_bookings = [{
          bookingId: booking_id,
          sentenceDetail: {
            releaseDate: 30.years.from_now.iso8601,
            sentenceStartDate: sentence_start.iso8601,
            homeDetentionCurfewEligibilityDate: 1.year.ago
          }
        }]

        stub_offender = {
          offenderNo: offender_no,
          bookingId: booking_id,
          dateOfBirth: 50.years.ago.iso8601
        }

        stub_offenders_for_prison(prison_code, [stub_offender], stub_bookings)

        stub_request(:get, "#{stub_api_host}/prisoners/#{offender_no}").
          to_return(status: 200, body: [stub_offender].to_json)

        stub_request(:post, "#{stub_api_host}/offender-assessments/CATEGORY").
          to_return(status: 200, body: {}.to_json)

        stub_request(:get, "#{stub_api_host}/bookings/#{booking_id}/mainOffence").
          to_return(status: 200, body: {}.to_json)

        stub_poms = [{ staffId: staff_id, position: RecommendationService::PRISON_POM }]

        stub_request(:get, "#{stub_api_host}/staff/roles/#{prison_code}/role/POM").
          to_return(status: 200, body: stub_poms.to_json)

        stub_request(:get, "#{stub_api_host}/staff/#{staff_id}").
          to_return(status: 200, body: {}.to_json)

        stub_request(:get, "#{stub_api_host}/staff/#{staff_id}/emails").
          to_return(status: 200, body: [].to_json)

        stub_request(:get, "#{stub_keyworker_host}/key-worker/#{prison_code}/offender/#{offender_no}").
          to_return(status: 200, body: {}.to_json)

        create(:allocation, nomis_offender_id: offender_no, primary_pom_nomis_id: staff_id)
        create(
          :case_information,
          nomis_offender_id: offender_no,
          case_allocation: 'NPS',
          welsh_offender: welsh
        )
      end

      describe 'the pom details page' do
        before { visit prison_pom_path(prison_code, staff_id) }

        context 'with a welsh offender' do
          let(:welsh) { 'Yes' }

          context 'with a sentence start date post-policy' do
            let(:sentence_start) { Time.zone.now }

            it 'shows their allocated case' do
              expect(page).to have_content(offender_no)
            end
          end

          context 'with a sentence start date pre-policy' do
            let(:sentence_start) { '01 Jan 2010'.to_date }

            it 'shows their allocated case' do
              expect(page).to have_content(offender_no)
            end
          end
        end

        context 'with an english offender' do
          let(:welsh) { 'No' }

          context 'with a sentence start date post-policy' do
            let(:sentence_start) { Time.zone.now }

            it 'shows their allocated case' do
              expect(page).to have_content(offender_no)
            end
          end

          context 'with a sentence start date pre-policy' do
            let(:sentence_start) { '01 Jan 2010'.to_date }

            it 'shows their allocated case' do
              expect(page).to have_content(offender_no)
            end
          end
        end
      end
    end
  end
end
