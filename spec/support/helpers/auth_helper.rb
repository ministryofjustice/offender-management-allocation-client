# frozen_string_literal: true

module AuthHelper
  T3 = 'https://gateway.t3.nomis-api.hmpps.dsd.io'
  ACCESS_TOKEN = 'an access token'

  def stub_auth_token
    allow(Nomis::Oauth::TokenService).to receive(:valid_token).and_return(OpenStruct.new(access_token: ACCESS_TOKEN))

    stub_request(:post, "#{T3}/auth/oauth/token?grant_type=client_credentials").
      to_return(status: 200, body: {
        "access_token": ACCESS_TOKEN,
        "token_type": "bearer",
        "expires_in": 1199,
        "scope": "readwrite"
      }.to_json, headers: {})
  end

  def stub_sso_data(prison, username = 'user')
    allow(Nomis::Oauth::TokenService).to receive(:valid_token).and_return(OpenStruct.new(access_token: 'token'))
    session[:sso_data] = { 'expiry' => Time.zone.now + 1.day,
                           'roles' => ['ROLE_ALLOC_MGR'],
                           'caseloads' => [prison],
                           'username' => username }
  end

  def stub_sso_pom_data(prison, username)
    allow(Nomis::Oauth::TokenService).to receive(:valid_token).and_return(OpenStruct.new(access_token: 'token'))
    session[:sso_data] = { 'expiry' => Time.zone.now + 1.day,
                           'roles' => ['ROLE_ALLOC_CASE_MGR'],
                           'caseloads' => [prison],
                           'username' => username }
  end
end
