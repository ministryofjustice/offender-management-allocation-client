# frozen_string_literal: true

class PrisonersController < PrisonsApplicationController
  include Sorting

  before_action :ensure_spo_user, except: [:show, :image]

  before_action :load_all_offenders, only: [:allocated, :missing_information, :unallocated, :new_arrivals, :search]

  def allocated
    load_summary :allocated
  end

  def missing_information
    load_summary :missing_information
  end

  def unallocated
    load_summary :unallocated
  end

  def new_arrivals
    load_summary :new_arrivals
  end

  def search
    @q = search_term
    offenders = SearchService.search_for_offenders(@q, @prison.all_policy_offenders)
    @offenders = get_slice_for_page(offenders)

    MetricsService.instance.increment_search_count
  end

  def show
    @prisoner = OffenderService.get_offender(params[:id])
    @tasks = PomTasks.new.for_offender(@prisoner)
    @allocation = AllocationHistory.find_by(nomis_offender_id: @prisoner.offender_no)

    if @allocation.present?
      @primary_pom_name = PrisonOffenderManagerService.fetch_pom_name(@allocation.primary_pom_nomis_id).
          titleize
    end

    if @allocation.present? && @allocation.secondary_pom_name.present?
      # POM-778 Just not covered by tests
      #:nocov:
      @secondary_pom_name = PrisonOffenderManagerService.fetch_pom_name(@allocation.secondary_pom_nomis_id).titleize
      #:nocov:
    end

    @keyworker = HmppsApi::KeyworkerApi.get_keyworker(
      active_prison_id, @prisoner.offender_no
    )

    @emails_sent_to_ldu = EmailHistory.sent_within_current_sentence(@prisoner, EmailHistory::OPEN_PRISON_COMMUNITY_ALLOCATION)
  end

  def image
    @prisoner = OffenderService.get_offender(params[:prisoner_id])
    image_data = @prisoner.get_image

    response.headers['Expires'] = 6.months.from_now.httpdate
    send_data image_data, type: 'image/jpg', disposition: 'inline'
  end

private

  def load_all_offenders
    @missing_info = @prison.missing_info
    @unallocated = @prison.unallocated
    @new_arrivals = @prison.new_arrivals
    @allocated = @prison.allocated.map do |offender|
      OffenderWithAllocationPresenter.new(offender, @prison.allocations.detect { |a| a.nomis_offender_id == offender.offender_no })
    end
  end

  def load_summary summary_type
    bucket = {
      unallocated: @unallocated,
      missing_information: @missing_info,
      new_arrivals: @new_arrivals,
      allocated: @allocated
    }.fetch(summary_type)

    offenders = sort_collection(bucket, default_sort: :last_name)

    @offenders = Kaminari.paginate_array(offenders).page(page)
  end

  def get_slice_for_page(offender_list)
    offenders = offender_list.map do |offender|
      OffenderWithAllocationPresenter.new(offender, @prison.allocations.detect { |a| a.nomis_offender_id == offender.offender_no })
    end
    Kaminari.paginate_array(offenders).page(page)
  end

  def page
    params.fetch('page', 1).to_i
  end

  def search_term
    # defaults to an empty string if the key 'q' can't be found
    params.fetch('q', '').strip
  end
end
