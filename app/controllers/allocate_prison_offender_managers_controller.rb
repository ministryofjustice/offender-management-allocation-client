class AllocatePrisonOffenderManagersController < ApplicationController
  before_action :authenticate_user

  def show; end

  def new
    response = OffenderService.new.get_offender(noms_id)
    @prisoner = response.data
  end

private

  def noms_id
    params.require(:noms_id)
  end
end
