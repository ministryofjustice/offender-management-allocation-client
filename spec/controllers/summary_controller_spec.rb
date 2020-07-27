require 'rails_helper'

RSpec.describe SummaryController, type: :controller do
  let(:poms) {
    [
      build(:pom,
            firstName: 'Alice',
            position: RecommendationService::PRISON_POM,
            staffId: 1
      )
    ]
  }

  let(:prison) { 'BRI' }

  before { stub_sso_data(prison, 'alice') }

  context 'with 2 offenders' do
    let(:today_plus_10) { (Time.zone.today + 10.days).to_s }
    let(:today_plus_13_weeks) { (Time.zone.today + 13.weeks).to_s }

    before do
      offenders = [
        { "bookingId": 754_208, "offenderNo": "G7514GW", "firstName": "BOB", "lastName": "SMITH",
          "dateOfBirth": "1995-02-02", "age": 34, "agencyId": prison, "categoryCode": "D", "imprisonmentStatus": "LR" },
        { "bookingId": 754_207, "offenderNo": "G1234GY", "firstName": "Indeter", "lastName": "Minate-Offender",
          "dateOfBirth": "1990-12-06", "age": 28, "agencyId": prison, "categoryCode": "C", "imprisonmentStatus": "LIFE" },
        { "bookingId": 754_206, "offenderNo": "G1234VV", "firstName": "ROSS", "lastName": "JONES",
          "dateOfBirth": "2001-02-02", "age": 18, "agencyId": prison, "categoryCode": "D", "imprisonmentStatus": "SENT03" },
        { "bookingId": 754_205, "offenderNo": "G4234GG", "firstName": "Fourth", "lastName": "Offender",
          "dateOfBirth": "2001-02-02", "age": 18, "agencyId": prison, "categoryCode": "D", "imprisonmentStatus": "SENT03" }
      ]

      bookings = [
        { "bookingId": 754_208, "offenderNo": "G7514GW", "firstName": "Indeter", "lastName": "Minate-Offender", "agencyLocationId": prison,
          "sentenceDetail": { "sentenceExpiryDate": "2014-02-16", "automaticReleaseDate": today_plus_10,
                              "licenceExpiryDate": "2014-02-07", "homeDetentionCurfewActualDate": today_plus_10,
                              "bookingId": 754_208, "sentenceStartDate": "2009-02-08", "automaticReleaseOverrideDate": "2012-03-17",
                              "nonDtoReleaseDate": "2012-03-17", "nonDtoReleaseDateType": "ARD", "confirmedReleaseDate": "2012-03-17",
                              "releaseDate": "2012-03-17" }, "dateOfBirth": "1953-04-15", "agencyLocationDesc": "LEEDS (HMP)",
          "internalLocationDesc": "A-4-013", "facialImageId": 1_399_838 },
        { "bookingId": 754_207, "offenderNo": "G1234GY", "firstName": "Indeter", "lastName": "Minate-Offender", "agencyLocationId": prison,
          "sentenceDetail": { "sentenceExpiryDate": "2014-02-16", "automaticReleaseDate": "2011-01-28",
                              "licenceExpiryDate": "2014-02-07", "homeDetentionCurfewEligibilityDate": "2011-11-07",
                              "bookingId": 754_207, "sentenceStartDate": "2009-02-08", "automaticReleaseOverrideDate": "2012-03-17",
                              "nonDtoReleaseDate": "2012-03-17", "nonDtoReleaseDateType": "ARD", "confirmedReleaseDate": "2012-03-17",
                              "releaseDate": "2012-03-17" }, "dateOfBirth": "1953-04-15", "agencyLocationDesc": "LEEDS (HMP)",
          "internalLocationDesc": "A-4-013", "facialImageId": 1_399_838 },
        { "bookingId": 754_206, "offenderNo": "G1234VV", "firstName": "ROSS", "lastName": "JONES", "agencyLocationId": prison,
          "sentenceDetail": { "sentenceExpiryDate": "2014-02-16", "automaticReleaseDate": today_plus_13_weeks,
                              "licenceExpiryDate": "2014-02-07",
                              "bookingId": 754_206, "sentenceStartDate": "2019-02-08",
                              "nonDtoReleaseDate": "2012-03-17", "nonDtoReleaseDateType": "ARD", "confirmedReleaseDate": "2012-03-17",
                              "releaseDate": "2012-03-17" }, "dateOfBirth": "1953-04-15", "agencyLocationDesc": "LEEDS (HMP)",
          "internalLocationDesc": "A-4-013", "facialImageId": 1_399_838 },
        { "bookingId": 754_205, "offenderNo": "G4234GG", "firstName": "Fourth", "lastName": "Offender", "agencyLocationId": prison,
          "sentenceDetail": { "sentenceExpiryDate": "2014-02-16", "automaticReleaseDate": today_plus_10,
                              "licenceExpiryDate": "2014-02-07", "homeDetentionCurfewActualDate": today_plus_10,
                              "bookingId": 754_205, "sentenceStartDate": "2019-02-08",
                              "nonDtoReleaseDate": "2012-03-17", "nonDtoReleaseDateType": "ARD", "confirmedReleaseDate": "2012-03-17",
                              "releaseDate": "2012-03-17" }, "dateOfBirth": "1953-04-15", "agencyLocationDesc": "LEEDS (HMP)",
          "internalLocationDesc": "A-4-013", "facialImageId": 1_399_838 }
      ]

      create(:case_information, case_allocation: 'NPS', nomis_offender_id: 'G4234GG')

      stub_offenders_for_prison(prison, offenders, bookings)
    end

    describe '#handover' do
      before do
        stub_movements
      end

      context 'when NPS case' do
        it 'returns cases that are within the thirty day window' do
          get :handovers, params: { prison_id: prison }
          expect(response).to be_successful
          expect(assigns(:offenders).map(&:offender_no)).to match_array(["G4234GG"])
        end
      end

      context 'when CRC case' do
        before do
          create(:case_information, case_allocation: 'CRC', nomis_offender_id: 'G1234VV')
        end

        pending 'returns cases that are within the thirty day window' do
          get :handovers, params: { prison_id: prison }
          expect(response).to be_successful
          expect(assigns(:offenders).map(&:offender_no)).to match_array(['G4234GG', "G1234VV"])
        end
      end
    end

    context 'when user is a POM' do
      before do
        stub_poms(prison, poms)
        stub_signed_in_pom(prison, 1, 'Alice')
        stub_request(:get, "https://gateway.t3.nomis-api.hmpps.dsd.io/elite2api/api/users/").
          to_return(status: 200, body: { staffId: 1 }.to_json, headers: {})
      end

      it 'is not visible' do
        get :pending, params: { prison_id: prison }
        expect(response).to redirect_to('/401')
      end
    end

    context 'without new arrivals' do
      before do
        stub_request(:post, "https://gateway.t3.nomis-api.hmpps.dsd.io/elite2api/api/movements/offenders?latestOnly=false&movementTypes=TRN").
          with(body: %w[G7514GW G1234GY G1234VV G4234GG].to_json).
          to_return(status: 200, body: [{ offenderNo: 'G7514GW', toAgency: prison, createDateTime: Date.new(2018, 10, 1) },
                                        { offenderNo: 'G1234VV', toAgency: prison, createDateTime: Date.new(2018, 9, 1) }].to_json)
      end

      it 'gets pending records' do
        get :pending, params: { prison_id: prison }
        # Expecting offender (2) to use sentenceStartDate as it is newer than last arrival date in prison
        expect(assigns(:offenders).map(&:awaiting_allocation_for).map { |x| Time.zone.today - x }).
          to match_array [Date.new(2009, 2, 8), Date.new(2018, 10, 1), Date.new(2019, 2, 8)]
      end

      it 'sorts ascending by default' do
        get :pending, params: { prison_id: prison, sort: 'last_name' } # Default direction is asc.
        expect(assigns(:offenders).map(&:last_name)).to eq(%w[JONES Minate-Offender SMITH])
      end

      it 'sorts descending' do
        get :pending, params: { prison_id: prison, sort: 'last_name desc' }

        expect(assigns(:offenders).map(&:last_name)).to eq(%w[SMITH Minate-Offender JONES])
      end
    end
  end

  context 'with enough offenders to page' do
    let(:prison) { 'LEI' }
    let(:range) { 0.upto(119) }
    let(:offenders) {
      range.map { |i|
        { "bookingId": i, "offenderNo": "G#{10_000 - i}GW", "firstName": "Offen", "lastName": "DerNum#{i}",
          "dateOfBirth": "1990-12-06", "age": 28, "agencyId": prison, "categoryCode": "C", "imprisonmentStatus": "LIFE" }
      }
    }
    let(:bookings) {
      range.map do |i|
        { "bookingId": i, "offenderNo": "G#{10_000 - i}GW", "firstName": "Offen", "lastName": "DerNum#{i}", "agencyLocationId": prison,
          "sentenceDetail": { "sentenceExpiryDate": "2014-02-16", "automaticReleaseDate": "2011-01-28",
                              "licenceExpiryDate": "2014-02-07", "homeDetentionCurfewEligibilityDate": "2011-11-07",
                              "bookingId": 754_207, "sentenceStartDate": "2019-02-08", "automaticReleaseOverrideDate": "2012-03-17",
                              "nonDtoReleaseDate": "2012-03-17", "nonDtoReleaseDateType": "ARD", "confirmedReleaseDate": "2012-03-17",
                              "releaseDate": "2012-03-17" }, "dateOfBirth": "1953-04-15", "agencyLocationDesc": "LEEDS (HMP)",
          "internalLocationDesc": "A-4-013", "facialImageId": 1_399_838 }
      end
    }
    let(:moves) {
      range.map { |i| "G#{10_000 - i}GW" }
    }
    let(:summary_offenders) { assigns(:offenders) }

    render_views

    before do
      stub_offenders_for_prison(prison, offenders, bookings)
      stub_request(:post, "https://gateway.t3.nomis-api.hmpps.dsd.io/elite2api/api/movements/offenders?latestOnly=false&movementTypes=TRN").
        with(body: moves.to_json).
        to_return(status: 200,
                  body: moves.map { |offender_no| { offenderNo: offender_no, toAgency: prison, createDateTime: Date.new(2018, 10, 1) } }.to_json)
    end

    it 'gets page 1 by default' do
      get :pending, params: { prison_id: prison }

      expect(summary_offenders.size).to eq(50)
      expect(summary_offenders.current_page).to eq(1)
      expect(summary_offenders.total_pages).to eq(3)
    end

    it 'gets page 2' do
      get :pending, params: { prison_id: prison, page: 2 }

      expect(summary_offenders.size).to eq(50)
      expect(summary_offenders.current_page).to eq(2)
      expect(summary_offenders.total_pages).to eq(3)
    end

    it 'gets page 3' do
      get :pending, params: { prison_id: prison, page: 3 }

      expect(summary_offenders.size).to eq(20)
      expect(summary_offenders.current_page).to eq(3)
      expect(summary_offenders.total_pages).to eq(3)
    end
  end

  context 'when sorting' do
    let(:prison) { 'BXI' }

    it 'handles trying to sort by missing field for allocated offenders' do
      # Allocated offenders do have to have their prison_arrival_date even if they don't use it
      # because we now need it to calculate the totals.
      stub_request(:post, "https://gateway.t3.nomis-api.hmpps.dsd.io/elite2api/api/movements/offenders?latestOnly=false&movementTypes=TRN").
        to_return(status: 200, body: [].to_json)

      # When viewing allocated, cannot sort by awaiting_allocation_for as it is not available and is
      # meaningless in this context. We do not want to crash if passed a field that is not searchable
      # within a specific context.
      offender_id = 'G7514GW'
      offenders = [{ "bookingId": 754_207, "offenderNo": offender_id, "firstName": "Indeter", "lastName": "Minate-Offender",
                     "dateOfBirth": "1990-12-06", "age": 28, "agencyId": prison, "categoryCode": "C", "imprisonmentStatus": "LIFE" }]

      bookings = [{ "bookingId": 754_207, "offenderNo": "G7514GW", "firstName": "Indeter", "lastName": "Minate-Offender", "agencyLocationId": prison,
                    "sentenceDetail": { "sentenceExpiryDate": "2014-02-16", "tariffDate": "2011-01-28",
                                        "bookingId": 754_207, "sentenceStartDate": "2009-02-08",
                                        "releaseDate": "2012-03-17" },
                    "dateOfBirth": "1953-04-15", "agencyLocationDesc": "LEEDS (HMP)",
                    "internalLocationDesc": "A-4-013", "facialImageId": 1_399_838 }]
      stub_offenders_for_prison(prison, offenders, bookings)

      create(:case_information, nomis_offender_id: offender_id)
      create(:allocation, nomis_offender_id: offender_id, primary_pom_nomis_id: 234, prison: prison)

      get :allocated, params: { prison_id: prison, sort: 'awaiting_allocation_for asc' }
      expect(assigns(:offenders).count).to eq(1)
    end
  end

  describe 'new arrivals feature' do
    before do
      inmates = offenders.map { |offender|
        {
          bookingId: offender[:booking_id],
          offenderNo: offender[:nomis_id],
          dateOfBirth: 30.years.ago.strftime('%F'),
          agencyId: offender[:prison_id]
        }
      }

      bookings = offenders.map { |offender|
        {
          bookingId: offender[:booking_id],
          sentenceDetail: {
            sentenceStartDate: offender[:sentence_start_date].strftime('%F'),
            conditionalReleaseDate: 30.years.from_now.strftime('%F')
          }
        }
      }

      stub_offenders_for_prison(prison, inmates, bookings)

      stub_request(:post, "https://gateway.t3.nomis-api.hmpps.dsd.io/elite2api/api/movements/offenders?latestOnly=false&movementTypes=TRN").
        to_return(status: 200, body: movements.to_json)
    end

    context 'with no movements and four offenders' do
      let(:offenders) { [offender_one, offender_two, offender_three, offender_four] }
      let(:offender_one) do
        {
          nomis_id: 'A1111AA',
          booking_id: 111_111,
          sentence_start_date: today
        }
      end

      let(:offender_two) do
        {
          nomis_id: 'B1111BB',
          booking_id: 222_222,
          sentence_start_date: today - 1.day
        }
      end

      let(:offender_three) do
        {
          nomis_id: 'C1111CC',
          booking_id: 333_333,
          sentence_start_date: today - 2.days
        }
      end

      let(:offender_four) do
        {
          nomis_id: 'D1111DD',
          booking_id: 444_444,
          sentence_start_date: today - 3.days
        }
      end

      let(:movements) { [] }

      context 'when today is Thursday' do
        let(:today) { 'Thu 17 Jan 2019'.to_date }

        it 'shows one new arrival' do
          Timecop.travel(today) do
            get :new_arrivals, params: { prison_id: prison }
            expect(assigns(:offenders).count).to eq 1
          end
        end

        it 'includes how recent those arrivals are' do
          Timecop.travel(today) do
            get :new_arrivals, params: { prison_id: prison }
            summary_offenders = assigns(:offenders).map { |o| [o.offender_no, o.awaiting_allocation_for] }.to_h
            expect(summary_offenders).to include(
              'A1111AA' => 0
            )
          end
        end

        it 'excludes arrivals from yesterday' do
          Timecop.travel(today) do
            get :new_arrivals, params: { prison_id: prison }
            summary_offenders = assigns(:offenders).map { |o| [o.offender_no, o.awaiting_allocation_for] }.to_h
            expect(summary_offenders.keys).not_to include('B1111BB')
          end
        end

        it 'includes yesterday arrivals in pending instead' do
          Timecop.travel(today) do
            get :pending, params: { prison_id: prison }
            summary_offenders = assigns(:offenders).map { |o| [o.offender_no, o.awaiting_allocation_for] }.to_h
            expect(summary_offenders.keys).to include('B1111BB')
          end
        end

        context 'with case information' do
          it 'does not show in new arrivals' do
            create(:case_information, nomis_offender_id: 'A1111AA')

            Timecop.travel(today) do
              get :new_arrivals, params: { prison_id: prison }
              summary_offenders = assigns(:offenders).map { |o| [o.offender_no, o.awaiting_allocation_for] }.to_h
              expect(summary_offenders.keys).not_to include('A1111AA')
            end
          end
        end
      end

      context 'when today is Monday' do
        let(:today) { 'Mon 14 Jan 2019'.to_date }

        it 'shows three new arrivals' do
          Timecop.travel(today) do
            get :new_arrivals, params: { prison_id: prison }
            expect(assigns(:offenders).count).to eq 3
          end
        end

        it 'includes arrivals from Saturday' do
          Timecop.travel(today) do
            get :new_arrivals, params: { prison_id: prison }
            summary_offenders = assigns(:offenders).map { |o| [o.offender_no, o.awaiting_allocation_for] }.to_h
            expect(summary_offenders.keys).to include('C1111CC')
          end
        end

        it 'excludes arrivals from Friday last week' do
          Timecop.travel(today) do
            get :new_arrivals, params: { prison_id: prison }
            summary_offenders = assigns(:offenders).map { |o| [o.offender_no, o.awaiting_allocation_for] }.to_h
            expect(summary_offenders.keys).not_to include('D1111DD')
          end
        end
      end
    end

    context 'with a movement arriving on Monday, 5pm' do
      let(:offenders) do
        [{
          nomis_id: 'A1111AA',
          booking_id: 111_111,
          sentence_start_date: '1 Jan 1980'.to_date,
          prison_id: prison
        }]
      end

      let(:movements) do
        [
          offenderNo: 'A1111AA',
          toAgency: prison,
          createDateTime: 'Tue 14 Jan 2020 17:00'.to_datetime
        ]
      end

      context 'when today is Tuesday, 8pm' do
        let(:today) { 'Tue 14 Jan 2020 20:00'.to_datetime }

        it 'shows that offender in new arrivals' do
          Timecop.travel(today) do
            get :new_arrivals, params: { prison_id: prison }

            expect(assigns(:offenders).map(&:offender_no)).to include('A1111AA')
          end
        end
      end

      context 'when today is Wed, 10am' do
        let(:today) { 'Wed 15 Jan 2020 10:00'.to_datetime }

        it 'does not show that offender in new arrivals' do
          Timecop.travel(today) do
            get :new_arrivals, params: { prison_id: prison }

            expect(assigns(:offenders).map(&:offender_no)).not_to include('A1111AA')
          end
        end

        it 'shows that offender as arriving one day ago' do
          Timecop.travel(today) do
            get :pending, params: { prison_id: prison }

            summary_offenders = assigns(:offenders).map { |o| [o.offender_no, o.awaiting_allocation_for] }.to_h

            expect(summary_offenders).to include('A1111AA' => 1)
          end
        end
      end
    end
  end
end
