module FeaturesHelper
  # Signs in a user which historically has always been an SPO. For backwards
  # compatability this continues to mock sso for an SPO, but we should move
  # in future to one of the explicit signin_*_user methods below.
  def signin_user(name = 'PK000223')
    signin_spo_user(name)
  end

  def signin_spo_user(name = 'PK000223')
    mock_sso_response(name, ['ROLE_ALLOC_MGR'])
  end

  def signin_pom_user(name = 'PK000223')
    mock_sso_response(name, ['ROLE_ALLOC_CASE_MGR'])
  end

  def mock_sso_response(name, roles)
    hmpps_sso_response = {
      'info' => double('user_info', username: name, active_caseload: 'LEI', caseloads: %w[LEI RSI], roles: roles),
      'credentials' => double('credentials', expires_at: Time.zone.local(2030, 1, 1).to_i,
                                             'authorities': roles)
    }

    OmniAuth.config.add_mock(:hmpps_sso, hmpps_sso_response)
  end
end
