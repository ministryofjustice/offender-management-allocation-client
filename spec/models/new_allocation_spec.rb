require 'rails_helper'

RSpec.describe NewAllocation, type: :model do
  describe 'associations' do
    subject { build(:new_allocation) }

    it { is_expected.to belong_to(:case_information) }
    it { is_expected.to belong_to(:pom_detail) }
  end

  describe 'scopes' do
    before do
      create_list(:new_allocation, 7, :coworking)
      create_list(:new_allocation, 11, :primary)
    end

    it 'can find primary allocations' do
      records = described_class.primary
      expect(records.count).to eq(11)
      expect(records.map(&:primary?)).to all be(true)
      expect(records.map(&:coworking?)).to all be(false)
    end

    it 'can find co-working allocations' do
      records = described_class.coworking
      expect(records.count).to eq(7)
      expect(records.map(&:primary?)).to all be(false)
      expect(records.map(&:coworking?)).to all be(true)
    end
  end

  context 'when a primary allocation already exists for the offender' do
    let(:case_info) { create(:case_information) }

    before do
      create(:new_allocation, :primary, case_information: case_info)
    end

    it 'does not allow a duplicate primary allocation to be created' do
      allocation = build(:new_allocation, :primary, case_information: case_info)
      expect(allocation.valid?).to be(false)
      expect(allocation.errors[:case_information]).to eq(["The offender already has an allocation of that type"])
    end
  end
end
