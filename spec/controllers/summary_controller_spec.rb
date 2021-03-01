# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SummaryController, type: :controller do
  let(:prison) { build(:prison).code }

  before { stub_sso_data(prison) }

  context 'with 4 offenders' do
    let(:today_plus_10_days) { (Time.zone.today + 10.days).to_s }
    let(:today_plus_13_weeks) { (Time.zone.today + 13.weeks).to_s }

    before do
      offenders = [
      build(:nomis_offender,
            offenderNo: "G7514GW",
            imprisonmentStatus: "LR",
            lastName: 'SMITH',
            sentence: attributes_for(:sentence_detail, sentenceStartDate: "2011-01-20")),
      build(:nomis_offender, offenderNo: "G1234GY", imprisonmentStatus: "LIFE",
            lastName: 'Minate-Offender',
            sentence: attributes_for(:sentence_detail,
                                     sentenceStartDate: "2009-02-08",
                                     automaticReleaseDate: "2011-01-28")),
      build(:nomis_offender, offenderNo: "G1234VV",
            lastName: 'JONES',
            sentence: attributes_for(:sentence_detail,
                                     sentenceStartDate: "2019-02-08",
                                     automaticReleaseDate: today_plus_13_weeks)),
      build(:nomis_offender, offenderNo: "G4234GG",
            imprisonmentStatus: "SENT03",
            firstName: "Fourth", lastName: "Offender",
            sentence: attributes_for(:sentence_detail,
                                     automaticReleaseDate: today_plus_10_days,
                                     homeDetentionCurfewActualDate: today_plus_10_days,
                                     sentenceStartDate: "2019-02-08",
                                     ))
      ]
      create(:case_information, case_allocation: 'NPS', nomis_offender_id: 'G4234GG')

      stub_offenders_for_prison(prison, offenders)
    end

    context 'without new arrivals' do
      before do
        stub_request(:post, "#{ApiHelper::T3}/movements/offenders?latestOnly=false&movementTypes=TRN").
          with(body: %w[G7514GW G1234GY G1234VV G4234GG].to_json).
          to_return(body: [attributes_for(:movement, offenderNo: 'G7514GW', toAgency: prison, movementDate: Date.new(2018, 10, 1).to_s),
                           attributes_for(:movement, offenderNo: 'G1234VV', toAgency: prison, movementDate: Date.new(2018, 9, 1).to_s)].to_json)
      end

      it 'gets pending records' do
        get :pending, params: { prison_id: prison }
        # Expecting offender (2) to use sentenceStartDate as it is newer than last arrival date in prison
        off = assigns(:offenders).map { |o| [o.offender_no, Time.zone.today - o.awaiting_allocation_for] }.to_h
        expect(off).to eq("G1234GY" => Date.new(2009, 2, 8),
                  "G7514GW" => Date.new(2018, 10, 1),
                  "G1234VV" => Date.new(2019, 2, 8))
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

  context 'when user is a POM' do
    let(:poms) {
      [
        build(:pom,
              firstName: 'Alice',
              position: RecommendationService::PRISON_POM,
              staffId: 1
        )
      ]
    }

    before do
      stub_poms(prison, poms)
      stub_signed_in_pom(prison, 1)
      stub_request(:get, "#{ApiHelper::T3}/users/").
        to_return(body: { staffId: 1 }.to_json)
    end

    it 'is not visible' do
      get :pending, params: { prison_id: prison }
      expect(response).to redirect_to('/401')
    end
  end

  context 'with enough offenders to page' do
    let(:offenders) { build_list(:nomis_offender, 120) }
    let(:moves) {
      offenders.map { |o| o.fetch(:offenderNo) }
    }
    let(:summary_offenders) { assigns(:offenders) }

    render_views

    before do
      stub_offenders_for_prison(prison, offenders)
      stub_request(:post, "#{ApiHelper::T3}/movements/offenders?latestOnly=false&movementTypes=TRN").
        with(body: moves.to_json).
        to_return(body: moves.map { |offender_no| attributes_for(:movement, offenderNo: offender_no, toAgency: prison, movementDate: Date.new(2018, 10, 1).to_s) }.to_json)
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
    context 'with allocated offenders' do
      let(:prison) { 'BXI' }

      it 'handles trying to sort by missing field for allocated offenders' do
        # Allocated offenders do have to have their prison_arrival_date even if they don't use it
        # because we now need it to calculate the totals.
        stub_request(:post, "#{ApiHelper::T3}/movements/offenders?latestOnly=false&movementTypes=TRN").
        to_return(body: [].to_json)

        # When viewing allocated, cannot sort by awaiting_allocation_for as it is not available and is
        # meaningless in this context. We do not want to crash if passed a field that is not searchable
        # within a specific context.
        offender_id = 'G7514GW'
        offenders = [build(:nomis_offender, offenderNo: offender_id)]
        stub_offenders_for_prison(prison, offenders)

        create(:case_information, nomis_offender_id: offender_id)
        create(:allocation, nomis_offender_id: offender_id, primary_pom_nomis_id: 234, prison: prison)

        get :allocated, params: { prison_id: prison, sort: 'awaiting_allocation_for asc' }
        expect(assigns(:offenders).count).to eq(1)
      end
    end

    context 'with unallocated offenders' do
      let(:today_plus_13_weeks) { (Time.zone.today + 13.weeks).to_s }
      let(:today_plus_7_weeks) { (Time.zone.today + 7.weeks).to_s }

      let(:offenders) do
        [

        build(:nomis_offender, offenderNo: "G7514GW", imprisonmentStatus: "LR"), # custody case
        build(:nomis_offender, offenderNo: "G1234VV", imprisonmentStatus: "SENT03",
              sentence: attributes_for(:sentence_detail, conditionalReleaseDate: today_plus_7_weeks)), # community case
        build(:nomis_offender, offenderNo: "G4234GG", imprisonmentStatus: "SENT03"), # custody case
        build(:nomis_offender, offenderNo: "G1234GY", imprisonmentStatus: "SENT03",
              sentence: attributes_for(:sentence_detail, sentenceStartDate: "2019-02-08",
                                       automaticReleaseDate: today_plus_13_weeks)) # community case
        ]
      end

      before do
        stub_request(:post, "#{ApiHelper::T3}/movements/offenders?latestOnly=false&movementTypes=TRN").
        to_return(body: [].to_json)

        offenders.each do |offender|
          create(:case_information, nomis_offender_id: offender[:offenderNo])
        end
      end

      it 'can sort by case_owner in ascending order' do
        stub_offenders_for_prison(prison, offenders)

        get :unallocated, params: { prison_id: prison, sort: 'case_owner asc' }

        expect(assigns(:offenders).first.pom_responsibility.supporting?).to eq(true)
        expect(assigns(:offenders).last.pom_responsibility.responsible?).to eq(true)
      end

      it 'can sort by case owner in descending order' do
        stub_offenders_for_prison(prison, offenders)

        get :unallocated, params: { prison_id: prison, sort: 'case_owner desc' }
        expect(assigns(:offenders).first.pom_responsibility.responsible?).to eq(true)
        expect(assigns(:offenders).last.pom_responsibility.supporting?).to eq(true)
      end
    end
  end

  describe 'new arrivals feature' do
    before do
      inmates = offenders.map { |offender|
        build(:nomis_offender,
              offenderNo: offender[:nomis_id],
              sentence: attributes_for(:sentence_detail,
                                       sentenceStartDate: offender.fetch(:sentence_start_date).strftime('%F')))
      }

      stub_offenders_for_prison(prison, inmates)

      stub_request(:post, "#{ApiHelper::T3}/movements/offenders?latestOnly=false&movementTypes=TRN").
        to_return(body: movements.to_json)
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
          attributes_for(:movement,
                         offenderNo: 'A1111AA',
                         toAgency: prison,
                         movementDate: '2020-01-14')
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
