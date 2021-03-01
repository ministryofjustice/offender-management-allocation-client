require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe 'returns the correct label' do
    it "for service provider CRC" do
      expect(service_provider_label('CRC')).to eq('Community Rehabilitation Company (CRC)')
    end

    it "for service provider NPS" do
      expect(service_provider_label('NPS')).to eq('National Probation Service (NPS)')
    end
  end

  describe 'displays mail_to link of a given email' do
    it 'displays alternative text if email not present' do
      email = nil

      expect(format_email(email)).to eq('(email address not found)')
    end

    it 'displays email address as mail_to link' do
      email = 'john.doe@example.com'

      expect(format_email(email)).to eq("<a href=\"mailto:john.doe@example.com\">john.doe@example.com</a>")
    end
  end
end
