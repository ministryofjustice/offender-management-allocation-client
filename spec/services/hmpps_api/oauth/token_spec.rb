require 'rails_helper'

describe HmppsApi::Oauth::Token do
  it 'can confirm if it is not expired' do
    access_token = generate_jwt_token
    token = described_class.new(access_token: access_token, expires_in: 4.hours)

    expect(token.needs_refresh?).to be(false)
  end

  it 'can confirm if it is expired' do
    access_token = generate_jwt_token('exp' => 4.hours.ago.to_i)
    token = described_class.new(access_token: access_token, expires_in: -4.hours)

    expect(token.needs_refresh?).to be(true)
  end

  it 'can retrieve the payload directly' do
    access_token = generate_jwt_token('exp' => 4.hours.from_now.to_i)
    token = described_class.new(access_token: access_token, expires_in: 4.hours)

    expect(token.needs_refresh?).to be(false)
  end
end
