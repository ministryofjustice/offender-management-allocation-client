# frozen_string_literal: true

class ApplicationController < ActionController::Base
  helper_method :current_user
  helper_method :caseloads, :current_user_is_spo?

  before_action :set_paper_trail_whodunnit

  def authenticate_user
    if sso_identity.absent? || session_expired?
      session[:redirect_path] = request.original_fullpath
      redirect_to '/auth/hmpps_sso'
    else
      redirect_to '/401' unless allowed?
    end
  end

  def current_user
    sso_identity.current_user
  end

  def current_user_is_spo?
    sso_identity.current_user_is_spo?
  end

  def ensure_admin_user
    unless current_user_is_spo?
      redirect_to '/401'
    end
  end

  def default_prison_code
    sso_identity.default_prison_code
  end

  def caseloads
    sso_identity.caseloads
  end

private

  def allowed?
    sso_identity.allowed?
  end

  def session_expired?
    sso_identity.session_expired?
  end

  def sso_identity
    @sso_identity ||= SsoIdentity.new session
  end
end
