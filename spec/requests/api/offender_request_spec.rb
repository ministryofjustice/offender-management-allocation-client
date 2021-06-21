require 'rails_helper'

RSpec.describe "OffenderApis", type: :request do
  let(:prison) { create(:prison) }
  let(:request_headers) {
    # Include an Authorization header to make the request valid
    { "Authorization" => auth_header }
  }

  context 'with an offender' do
    let!(:db_offender) { create(:offender, early_allocations: early_allocations) }
    let!(:case_info) { create(:case_information, offender: db_offender) }
    let(:offender) {
      build(:nomis_offender, offenderNo: offender_no, agencyId: prison.code,
                           sentence: attributes_for(:sentence_detail, licenceExpiryDate: sentence_end_date))
    }
    let(:offender_no) { db_offender.nomis_offender_id }
    let(:response_body) { JSON.parse(response.body).symbolize_keys }

    before do
      stub_offender offender
      get "/api/offenders/#{offender_no}.json", headers: request_headers
      expect(response.status).to eq(200)
    end

    context 'when sentence is current' do
      let(:sentence_end_date) { Time.zone.today + 2.years }

      context 'without an early allocation' do
        let(:early_allocations) { [] }

        it 'can get an offender' do
          expect(response_body).to eq(offender_no: offender_no, early_allocation_eligibility_status: false)
        end
      end

      context 'with an early allocation' do
        let(:early_allocations) { [build(:early_allocation)] }

        it 'can get an offender' do
          expect(response_body).to eq(offender_no: offender_no, early_allocation_eligibility_status: true)
        end
      end
    end

    context 'when sentence hasnt quite expired' do
      let(:early_allocations) { [build(:early_allocation)] }
      let(:sentence_end_date) { Time.zone.today + 1.day }

      it 'can get an offender' do
        expect(response_body).to eq(offender_no: offender_no, early_allocation_eligibility_status: true)
      end
    end

    context 'when sentence has expired' do
      let(:early_allocations) { [build(:early_allocation)] }
      let(:sentence_end_date) { Time.zone.today - 1.day }

      it 'is false' do
        expect(response_body).to eq(offender_no: offender_no, early_allocation_eligibility_status: false)
      end
    end
  end

  context 'without an offender' do
    let(:offender_no) { build(:case_information).nomis_offender_id }

    before do
      stub_non_existent_offender offender_no
    end

    it 'can returns 404' do
      get "/api/offenders/#{offender_no}.json", headers: request_headers
      expect(response.status).to eq(404)
    end
  end
end
