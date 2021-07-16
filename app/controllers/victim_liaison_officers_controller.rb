# frozen_string_literal: true

class VictimLiaisonOfficersController < PrisonsApplicationController
  before_action :load_offender
  before_action :find_vlo, only: [:edit, :update, :destroy, :delete]
  before_action :store_referrer_in_session, only: [:new, :edit, :delete]
  before_action :set_referrer

  # we need to record users first name and last name for audit purposes
  # (as we can't rely on their details forever being available on NOMIS)
  # and we also record the context prison as the case history is organised
  # in that way.
  def info_for_paper_trail
    user = HmppsApi::PrisonApi::UserApi.user_details(current_user)
    {
        user_first_name: user.first_name,
        user_last_name: user.last_name,
        prison: active_prison_id
    }
  end

  def new
    @vlo = @offender.victim_liaison_officers.new
  end

  def create
    @vlo = @offender.victim_liaison_officers.new vlo_parameters

    if @vlo.save
      redirect_to referrer
    else
      render 'new'
    end
  end

  def edit; end

  def update
    if @vlo.update vlo_parameters
      redirect_to referrer
    else
      render 'edit'
    end
  end

  def delete; end

  def destroy
    @vlo.destroy
    redirect_to referrer
  end

private

  def find_vlo
    @vlo = VictimLiaisonOfficer.find params[:id]
  end

  def vlo_parameters
    params.require(:victim_liaison_officer).permit(:first_name, :last_name, :email)
  end

  def load_offender
    @offender = OffenderService.get_offender(params[:prisoner_id])
  end
end
