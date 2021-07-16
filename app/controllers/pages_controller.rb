# frozen_string_literal: true

class PagesController < ApplicationController
  layout 'errors_and_contact'

  def contact_us
    if current_user.present?
      @user = HmppsApi::PrisonApi::UserApi.user_details(current_user)
      @contact = ContactSubmission.new(email_address: @user.email_address.first,
                                       name: @user.full_name_ordered,
                                       prison: Prison.find(@user.active_case_load_id).name
      )
    else
      @contact = ContactSubmission.new
    end
  end

  def create_contact_us
    @user = HmppsApi::PrisonApi::UserApi.user_details(current_user) if current_user.present?
    @contact = ContactSubmission.new(
      name: help_params[:name],
      job_type: help_params[:job_type],
      email_address: help_params[:email_address],
      prison: help_params[:prison],
      message: help_params[:message],
      user_agent: request.headers['HTTP_USER_AGENT'],
      referrer: request.referer
    )
    if @contact.save
      ZendeskTicketsJob.perform_later(@contact) if Rails.configuration.zendesk_enabled

      redirect_path
    else
      render :contact_us
    end
  end

  def help; end

  def contact; end

  def whats_new; end

private

  def redirect_path
    if current_user.present?
      # POM_778: just not covered by tests
      #:nocov:
      redirect_to prison_dashboard_index_path(@user.active_case_load_id)
      #:nocov:
    else
      redirect_to help_path
    end
    flash[:notice] = 'Thank you for your message. We aim to reply within 2 working days.'
  end

  def help_params
    params.permit(:message, :email_address, :name, :prison, :job_type)
  end
end
