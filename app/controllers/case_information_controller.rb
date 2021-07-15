# frozen_string_literal: true

class CaseInformationController < PrisonsApplicationController
  before_action :set_prisoner_from_url, only: [:new, :edit, :edit_prd, :update_prd, :show]
  before_action :set_case_info, only: [:edit, :show]

  before_action :set_referrer
  before_action :store_referrer_in_session, only: [:edit_prd, :edit]

  def new
    @case_info = Offender.find_by!(nomis_offender_id: nomis_offender_id_from_url).build_case_information
  end

  def edit; end

  # Just edit the parole_review_date field
  def edit_prd
    @parole_form = ParoleReviewDateForm.new
  end

  def update_prd
    @parole_form = ParoleReviewDateForm.new parole_review_date_params
    if @parole_form.valid?
      ParoleRecord.find_or_create_by!(nomis_offender_id: nomis_offender_id_from_url) do |parole|
        parole.update(parole_review_date: @parole_form.parole_review_date)
      end
      redirect_to referrer
    else
      render 'edit_prd'
    end
  end

  def show
    @delius_errors = DeliusImportError.where(nomis_offender_id: nomis_offender_id_from_url)
  end

  def create
    prisoner = Offender.find_by! nomis_offender_id: case_information_params[:nomis_offender_id]
    @case_info = prisoner.build_case_information(
      nomis_offender_id: case_information_params[:nomis_offender_id],
      tier: case_information_params[:tier],
      probation_service: case_information_params[:probation_service],
      case_allocation: case_information_params[:case_allocation],
      manual_entry: true
    )

    if @case_info.save
      if params.fetch(:commit) == 'Save'
        redirect_to missing_information_prison_prisoners_path(active_prison_id,
                                                              sort: params[:sort],
                                                              page: params[:page]
                    )
      else
        redirect_to prison_prisoner_staff_index_path(active_prison_id,  @case_info.nomis_offender_id)
      end
    else
      @prisoner = prisoner(case_information_params[:nomis_offender_id])
      render :new
    end
  end

  def update
    @case_info = Offender.find_by!(nomis_offender_id: case_information_params[:nomis_offender_id]).case_information
    @prisoner = prisoner(case_information_params[:nomis_offender_id])
    # Nothing here can fail due to radio buttons being unselectable
    @case_info.update!(case_information_params.merge(manual_entry: true))
    redirect_to referrer
  end

private

  def set_prisoner_from_url
    @prisoner = prisoner(nomis_offender_id_from_url)
  end

  def set_case_info
    prisoner = Offender.find_by!(nomis_offender_id: nomis_offender_id_from_url)
    @case_info = prisoner.case_information || prisoner.build_case_information
  end

  def prisoner(nomis_id)
    @prisoner ||= OffenderService.get_offender(nomis_id)
  end

  def nomis_offender_id_from_url
    params.require(:prisoner_id)
  end

  def case_information_params
    params.require(:case_information).
      permit(:nomis_offender_id, :tier, :case_allocation, :probation_service)
  end

  def parole_review_date_params
    params.require(:parole_review_date_form).
      permit(:parole_review_date)
  end
end
