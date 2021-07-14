# frozen_string_literal: true

module FeaturesHelper
  def signin_spo_user(prisons = nil)
    if prisons.nil?
      mock_sso_response('MOIC_POM', [SsoIdentity::SPO_ROLE], Prison.all.pluck(:code))
    else
      mock_sso_response('MOIC_POM', [SsoIdentity::SPO_ROLE], prisons)
    end
    stub_user(staff_id: 1)
  end

  # def signin_spo_user(prisons = %w[LEI RSI], name = 'MOIC_POM')
  #   mock_sso_response(name, [SsoIdentity::SPO_ROLE], prisons)
  #   stub_user(staff_id: 1)
  # end

  def stub_signin_spo(pom, prisons = ['LEI'])
    stub_auth_token
    signin_spo_user(prisons)
    stub_spo_user(pom)
  end

  def stub_spo_user(pom)
    stub_request(:get, "#{ApiHelper::T3}/users/MOIC_POM").
        to_return(body: { 'staffId': pom.staff_id }.to_json)
    stub_request(:get, "#{ApiHelper::T3}/staff/#{pom.staff_id}/emails").
        to_return(body: pom.emails.to_json)
  end

  def signin_spo_pom_user(prisons = %w[LEI RSI], name = 'MOIC_POM')
    mock_sso_response(name, [SsoIdentity::SPO_ROLE, SsoIdentity::POM_ROLE], prisons)
    stub_user(staff_id: 1)
  end

  def signin_global_admin_user
    mock_sso_response('MOIC_POM', [SsoIdentity::SPO_ROLE, SsoIdentity::ADMIN_ROLE], PrisonService.prison_codes)
  end

  def signin_pom_user prisons = %w[LEI RSI]
    mock_sso_response('MOIC_POM', [SsoIdentity::POM_ROLE], prisons)
  end

  def mock_sso_response(username, roles, prisons)
    hmpps_sso_response = {
      'info' => double('user_info', username: username, active_caseload: prisons.first, caseloads: prisons, roles: roles),
      'credentials' => double('credentials', expires_at: Time.zone.local(2030, 1, 1).to_i,
                                             'authorities': roles)
    }

    OmniAuth.config.add_mock(:hmpps_sso, hmpps_sso_response)
  end

  def stub_user(username: 'MOIC_POM', staff_id:)
    stub_request(:get, "#{ApiHelper::T3}/users/#{username}").
      to_return(body: { 'staffId': staff_id }.to_json)
    stub_request(:get, "#{ApiHelper::T3}/staff/#{staff_id}/emails").
      to_return(body: [].to_json)
  end

  def wait_for(maximum_wait_in_seconds = 10)
    Selenium::WebDriver::Wait.new(timeout: maximum_wait_in_seconds).until { yield }
  end

  def execute_in_new_tab
    current_tab = page.current_window
    new_tab = page.open_new_window

    switch_to_window(new_tab)

    yield

    switch_to_window(current_tab)

    new_tab.close
  end
end
