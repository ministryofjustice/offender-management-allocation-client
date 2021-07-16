require 'rails_helper'

RSpec.describe VictimLiaisonOfficer, type: :model do
  it 'validates presence of first, last and email' do
    expect(subject).to validate_presence_of :first_name
    expect(subject).to validate_presence_of :last_name
    expect(subject).to validate_presence_of :email
  end

  context 'with an offender record' do
    before do
      create(:offender, victim_liaison_officers: [build(:victim_liaison_officer)])
    end

    let(:offender) { Offender.last }

    it 'checks the format of emails' do
      expect(build(:victim_liaison_officer)).to be_valid
      expect(build(:victim_liaison_officer, email: 'fred@exmaple.com')).to be_valid
      expect(build(:victim_liaison_officer, email: 'BOGUS !')).not_to be_valid
    end

    it 'belongs to a offender record and is destroyed with it' do
      expect {
        offender.destroy
      }.to change(described_class, :count).by(-1)
    end
  end
end
