# frozen_string_literal: true

class SsoIdentity
  POM_ROLE = 'ROLE_ALLOC_CASE_MGR'
  SPO_ROLE = 'ROLE_ALLOC_MGR'
  ADMIN_ROLE = 'ROLE_MOIC_ADMIN'

  def initialize(session)
    # Symbolize keys to avoid differences between different session storage adapters.
    # Cookie-backed sessions seem to return keys as strings, whereas cache-backed sessions
    # seem to return keys as symbols.
    @sso_identity = session[:sso_data]&.symbolize_keys
  end

  def absent?
    @sso_identity.nil?
  end

  def to_s
    current_user
  end

  def current_user
    @sso_identity[:username] if @sso_identity.present?
  end

  def current_user_is_spo?
    roles.include?(SPO_ROLE)
  end

  # This role is granted to the service team to give them 'admin' priviledges
  # such as editing teams and changing switch values
  def current_user_is_admin?
    roles.include?(ADMIN_ROLE)
  end

  def current_user_is_pom?
    roles.include?(POM_ROLE)
  end

  def default_prison_code
    @sso_identity[:active_caseload] if @sso_identity.present?
  end

  def caseloads
    if @sso_identity.blank?
      []
    else
      @sso_identity.fetch(:caseloads).reject { |c| c.casecmp('NWEB') == 0 }
    end
  end

  def allowed?
    roles.include?('ROLE_ALLOC_MGR') || roles.include?('ROLE_ALLOC_CASE_MGR')
  end

  def session_expired?
    Time.current > Time.zone.at(@sso_identity.fetch(:expiry))
  end

private

  def roles
    @roles ||= if @sso_identity.present?
                 @sso_identity[:roles]
               else
                 # POM-778 Just not covered by tests
                 #:nocov:
                 []
                 #:nocov:
               end
  end
end
