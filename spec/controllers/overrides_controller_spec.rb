require 'rails_helper'

RSpec.xdescribe OverridesController, :allocation, type: :controller do
  before do
    stub_sso_data(prison)
  end

  let(:prison) { 'WEI' }
  let(:nomis_staff_id) { 'A12345' }
  let(:nomis_offender_id) { 'B44455' }

  let(:params) do
    { prison_id: prison }
  end

  let(:override_params) do
    {
      override: { nomis_offender_id: nomis_offender_id,
                  nomis_staff_id: nomis_staff_id,
                  more_detail: nil,
                  suitability_detail: "Too high risk",
                  override_reasons: ["continuity"]
      }
    }
  end

  context 'without an allocation' do
    it 'redirects to confirm #allocation' do
      post :create, params: params.merge(override_params)

      expect(response).to redirect_to prison_confirm_allocation_path(prison, nomis_offender_id, nomis_staff_id)
    end
  end

  context 'with an allocation' do
    it 'redirects to confirm#reallocation' do
      create(:allocation, nomis_offender_id: nomis_offender_id, primary_pom_nomis_id: nomis_staff_id)
      post :create, params: params.merge(override_params)

      expect(response).to redirect_to prison_confirm_reallocation_path(prison, nomis_offender_id, nomis_staff_id)
    end
  end

  context 'with an inactive allocation' do
    before do
      create(:allocation, :release, nomis_offender_id: nomis_offender_id)
    end

    it 'redirects to confirm#allocation' do
      post :create, params: params.merge(override_params)
      expect(response).to redirect_to prison_confirm_allocation_path(prison, nomis_offender_id, nomis_staff_id)
    end
  end
end
