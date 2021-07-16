# frozen_string_literal: true

module AuthHelper
  ACCESS_TOKEN = Struct.new(:access_token).new('an-access-token')

  def auth_header
    oauth_client = HmppsApi::Oauth::Client.new(Rails.configuration.nomis_oauth_host)
    route = "/auth/oauth/token?grant_type=client_credentials"
    response = oauth_client.post(route)
    access_token = response.fetch("access_token")
    "Bearer #{access_token}"
  end

  def stub_auth_token
    allow(HmppsApi::Oauth::TokenService).to receive(:valid_token).and_return(ACCESS_TOKEN)

    stub_request(:post, "#{ApiHelper::AUTH_HOST}/auth/oauth/token?grant_type=client_credentials").
      to_return(body: {
        "access_token": ACCESS_TOKEN.access_token,
        "token_type": "bearer",
        "expires_in": 1199,
        "scope": "readwrite"
      }.to_json)
  end

  def stub_sso_data(prison, username: 'user', roles: [SsoIdentity::SPO_ROLE], emails: [])
    allow(HmppsApi::Oauth::TokenService).to receive(:valid_token).and_return(ACCESS_TOKEN)
    session[:sso_data] = { 'expiry' => Time.zone.now + 1.day,
                           'roles' => roles,
                           'caseloads' => [prison],
                           'username' => username }
    stub_request(:get, "#{ApiHelper::T3}/users/#{username}").
        to_return(body: { 'staffId': 754_732 }.to_json)
    stub_request(:get, "#{ApiHelper::T3}/staff/754732/emails").
        to_return(body: emails.to_json)
  end
end
