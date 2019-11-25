# frozen_string_literal: true

class EarlyAllocationsController < PrisonsApplicationController
  before_action :load_prisoner

  def new
    case_info = CaseInformation.find_by offender_id_from_url
    @early_assignment = case_info.early_allocations.new
    if case_info.local_divisional_unit.try(:email_address)
      render
    else
      render 'dead_end'
    end
  end

  def create
    @early_assignment = EarlyAllocation.new early_allocation_params.merge(offender_id_from_url)
    if @early_assignment.save
      if @early_assignment.eligible?
        AutoEarlyAllocationEmailJob.perform_later(@prison.code, @offender.offender_no, Base64.encode64(pdf_as_string))
        render 'eligible'
      else
        render 'ineligible'
      end
    else
      @early_assignment.errors.delete(:stage2_validation)
      render create_error_page
    end
  end

  # record a community decision (changing 'maybe' into a yes or a no)
  def edit
    @early_assignment = EarlyAllocation.where(offender_id_from_url).last
  end

  def update
    @early_assignment = EarlyAllocation.where(offender_id_from_url).last

    if @early_assignment.update(community_decision_params)
      redirect_to prison_prisoner_path(@prison.code, @early_assignment.nomis_offender_id)
    else
      render 'edit'
    end
  end

  def discretionary
    @early_assignment = EarlyAllocation.new early_allocation_params.merge(offender_id_from_url)
    if @early_assignment.save
      CommunityEarlyAllocationEmailJob.perform_later(@prison.code,
                                                     @offender.offender_no,
                                                     Base64.encode64(pdf_as_string))
      render
    else
      render 'stage3'
    end
  end

  def show
    @early_assignment = EarlyAllocation.find_by!(offender_id_from_url)

    respond_to do |format|
      format.pdf {
        # disposition 'attachment' is the default for send_data
        send_data pdf_as_string
      }
    end
  end

private

  def load_prisoner
    @offender = OffenderService.get_offender(params[:prisoner_id])
    @allocation = Allocation.find_by!(offender_id_from_url)
    @pom = PrisonOffenderManagerService.get_pom_at(@prison.code, @allocation.primary_pom_nomis_id)
  end

  def pdf_as_string
    view_context.render_early_alloc_pdf(early_assignment: @early_assignment,
                                        offender: @offender,
                                        pom: @pom,
                                        allocation: @allocation).render
  end

  def create_error_page
    if !@early_assignment.stage2_validation?
      stage1_error_page
    else
      stage2_error_page
    end
  end

  def stage1_error_page
    if @early_assignment.any_stage1_field_errors?
      'new'
    else
      'stage2'
    end
  end

  def stage2_error_page
    if @early_assignment.any_stage2_field_errors?
      'stage2'
    else
      'stage3'
    end
  end

  def community_decision_params
    params.fetch(:early_allocation, {}).permit(:community_decision).merge(recording_community_decision: true)
  end

  def early_allocation_params
    params.require(:early_allocation).
      permit(EarlyAllocation::STAGE1_BOOLEAN_FIELDS +
                EarlyAllocation::ALL_STAGE2_FIELDS +
                [:oasys_risk_assessment_date_dd,
                 :oasys_risk_assessment_date_mm,
                 :oasys_risk_assessment_date_yyyy,
                 :oasys_risk_assessment_date,
                 :stage2_validation,
                 :stage3_validation,
                 :reason,
                 :approved])
  end

  def offender_id_from_url
    { nomis_offender_id: params[:prisoner_id] }
  end
end
