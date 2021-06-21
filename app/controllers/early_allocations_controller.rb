# frozen_string_literal: true

class EarlyAllocationsController < PrisonsApplicationController
  before_action :load_prisoner

  def index
    @early_allocations = EarlyAllocation.where(offender_id_from_url).order(created_at: :desc)
  end

  def new
    @early_allocation = EarlyAllocationDateForm.new offender_id_from_url
    if @prisoner.ldu_email_address.present?
      render
    else
      render 'dead_end'
    end
  end

  def oasys_date
    form_params = oasys_date_params.merge(offender_id_from_url)
    form = EarlyAllocationDateForm.new form_params
    if form.valid?
      @early_allocation = EarlyAllocation.new form_params.merge(default_params)
      render 'eligible'
    else
      @early_allocation = form
      render 'new'
    end
  end

  def eligible
    form_params = eligible_params.merge(offender_id_from_url)
    form = EarlyAllocationEligibleForm.new form_params
    if form.valid?
      @early_allocation = EarlyAllocation.new form_params.merge(default_params)
      if @early_allocation.eligible?
        @early_allocation.save!
        if @prisoner.within_early_allocation_window?
          @prisoner.trigger_early_allocation_event
          AutoEarlyAllocationEmailJob.perform_later(@prison, @prisoner.offender_no, Base64.encode64(pdf_as_string))
        end
        render 'landing_eligible'
      else
        @early_allocation = EarlyAllocationDiscretionaryForm.new form_params
        render 'discretionary'
      end
    else
      @early_allocation = form
      render 'eligible'
    end
  end

  def discretionary
    form_params = discretionary_params.merge(offender_id_from_url)
    form = EarlyAllocationDiscretionaryForm.new form_params
    if form.valid?
      @early_allocation = EarlyAllocation.new form_params.merge(default_params)
      if @early_allocation.discretionary?
        render 'confirm_with_reason'
      else
        @early_allocation.save!
        render 'landing_ineligible'
      end
    else
      @early_allocation = form
      render 'discretionary'
    end
  end

  def confirm_with_reason
    @early_allocation = EarlyAllocation.new early_allocation_params.merge(offender_id_from_url)
    if @early_allocation.save
      if @prisoner.within_early_allocation_window?
        CommunityEarlyAllocationEmailJob.perform_later(@prison,
                                                       @prisoner.offender_no,
                                                       Base64.encode64(pdf_as_string))
      end
      render 'landing_discretionary'
    else
      render
    end
  end

  # record a community decision (changing 'maybe' into a yes or a no)
  # can only be performed on the last early allocation record
  def edit
    @early_allocation = @prisoner.early_allocations.last
  end

  def update
    @early_allocation = @prisoner.early_allocations.last

    if @early_allocation.update(community_decision_params)
      @prisoner.trigger_early_allocation_event
      redirect_to prison_prisoner_path(@prison.code, @early_allocation.nomis_offender_id)
    else
      render 'edit'
    end
  end

  def show
    @early_allocation = EarlyAllocation.where(id: params[:id]).where(offender_id_from_url).first!
    @referrer = request.referer

    respond_to do |format|
      format.pdf {
        # disposition 'attachment' is the default for send_data
        send_data pdf_as_string
      }
      format.html
    end
  end

private

  def load_prisoner
    @prisoner = OffenderService.get_offender(params[:prisoner_id])
  end

  def pdf_as_string
    allocation = AllocationHistory.find_by!(offender_id_from_url)
    pom = @prison.get_single_pom(allocation.primary_pom_nomis_id)

    view_context.render_early_alloc_pdf(early_allocation: @early_allocation,
                                        offender: @prisoner,
                                        pom: pom,
                                        allocation: allocation).render
  end

  def community_decision_params
    params.fetch(:early_allocation, {}).permit(:community_decision).
        merge(updated_by_firstname: @current_user.first_name,
              updated_by_lastname: @current_user.last_name)
  end

  def eligible_params
    params.require(:early_allocation).
      permit(EarlyAllocation::ELIGIBLE_BOOLEAN_FIELDS +
                [:oasys_risk_assessment_date])
  end

  def oasys_date_params
    params.fetch(:early_allocation, {}).permit(:oasys_risk_assessment_date)
  end

  def discretionary_params
    params.require(:early_allocation).
      permit(EarlyAllocation::ELIGIBLE_FIELDS + EarlyAllocation::ALL_DISCRETIONARY_FIELDS)
  end

  def early_allocation_params
    params.require(:early_allocation).
      permit(EarlyAllocation::ELIGIBLE_BOOLEAN_FIELDS +
                EarlyAllocation::ALL_DISCRETIONARY_FIELDS +
                [:oasys_risk_assessment_date,
                 :reason,
                 :approved]).merge(default_params)
  end

  def default_params
    { prison: active_prison_id,
        created_within_referral_window: @prisoner.within_early_allocation_window?,
        created_by_firstname: @current_user.first_name,
        created_by_lastname: @current_user.last_name }
  end

  def offender_id_from_url
    { nomis_offender_id: params[:prisoner_id] }
  end
end
