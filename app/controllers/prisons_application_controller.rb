# frozen_string_literal: true

# This class is inherited by all controllers under the /prisons route
# so that they have @prison and active_prison_id available
class PrisonsApplicationController < ApplicationController
  include Sorting

  before_action :authenticate_user, :check_prison_access, :load_staff_member, :service_notifications, :load_roles

protected

  def active_prison_id
    params[:prison_id]
  end

  def ensure_pom
    unless current_user_is_pom?
      redirect_to '/401'
    end
  end

  def current_user_is_pom?
    sso_identity.current_user_is_pom? && @current_user.has_pom_role?
  end

private

  def load_roles
    @is_pom = current_user_is_pom?
    @is_spo = current_user_is_spo?
  end

  def check_prison_access
    unless Prison.exists?(code: active_prison_id)
      redirect_to('/401')
      return
    end

    return redirect_to('/401') if caseloads.nil? || !caseloads.include?(active_prison_id)

    @prison = Prison.find(active_prison_id)
    @caseloads = caseloads
  end

  def load_staff_member
    user = HmppsApi::PrisonApi::UserApi.user_details(current_user)
    @current_user = StaffMember.new(@prison, user.staff_id)
    @staff_id = user.staff_id
  end

  def service_notifications
    roles = [current_user_is_spo? ? 'SPO' : nil, sso_identity.current_user_is_pom? ? 'POM' : nil].compact
    @service_notifications = ServiceNotificationsService.notifications(roles)
  end

  def page
    params.fetch('page', 1).to_i
  end

  def set_referrer
    @referrer = referrer
  end

  def referrer
    session[:referrer] || request.referer || root_path
  end

  def referrer_or_root
    request.referer || root_path
  end

  def store_referrer_in_session
    session[:referrer] = request.referer
  end
end
