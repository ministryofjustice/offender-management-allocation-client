# frozen_string_literal: true

module Api
  class OffendersController < Api::ApiController
    respond_to :json

    def show
      @offender = OffenderService.get_offender(offender_number)
      render_404('Not found') if @offender.nil?
    end

  private

    def offender_number
      params.require(:nomis_offender_id)
    end
  end
end
