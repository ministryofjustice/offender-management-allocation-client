require 'rails_helper'

RSpec.describe EarlyAllocationEventJob, type: :job do
  let(:prison) { create(:prison) }
  let(:offender) { build(:offender) }

  before do
    stub_offender(build(:nomis_offender, offenderNo: offender.nomis_offender_id, agencyId: prison.code))
    expect(EarlyAllocationEventService).to receive(:send_early_allocation)
  end

  it 'sends the event via the job' do
    described_class.perform_now offender.nomis_offender_id
  end
end
