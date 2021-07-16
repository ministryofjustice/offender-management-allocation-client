require 'rails_helper'

RSpec.feature "Update case information from allocation page", type: :feature do
  let(:offender) { build(:nomis_offender, complexityLevel: 'high', agencyId: prison.code) }
  let(:offenders) { [offender] }
  let(:pom) { build(:pom) }
  let(:spo) { build(:pom) }
  let(:prison) { create(:prison) }
  let(:offender_no) { offender.fetch(:offenderNo) }

  before do
    create(:allocation_history, nomis_offender_id: offender.fetch(:offenderNo), primary_pom_nomis_id: pom.staff_id,  prison: prison.code)
    create(:case_information, offender: build(:offender, nomis_offender_id: offender.fetch(:offenderNo)))

    stub_offenders_for_prison(prison.code, offenders)
    stub_signin_spo(spo, [prison.code])
    stub_poms(prison.code, [pom, spo])
    stub_keyworker(prison.code, offender.fetch(:offenderNo), build(:keyworker))
  end

  context 'when updating the tiering' do
    it 'returns to the prisoner Allocation information page', :js do
      visit prison_prisoner_allocation_path(prison_id: prison.code, prisoner_id: offender.fetch(:offenderNo))

      # This takes you to the change case information edit page
      within(:css, "td#tier") do
        click_link('Change')
      end

      # This returns you back from where you came (the Allocation information page)
      click_on('Update')

      expect(page).to have_current_path(prison_prisoner_allocation_path(prison_id: prison.code, prisoner_id: offender.fetch(:offenderNo)))
    end
  end
end
