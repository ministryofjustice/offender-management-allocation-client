# frozen_string_literal: true

class TasksController < PrisonsApplicationController
  breadcrumb 'Case updates needed', ''

  before_action :ensure_pom

  def index
    @pomtasks = tasks_for_offenders(caseload)
  end

private

  def tasks_for_offenders(allocations)
    # For each passed AllocationWithSentence we want to find out if the offender
    # requires any changes to it.  If so we will construct a PomTaskPresenter and
    # return it. Otherwise nil.

    offender_nos = allocations.map(&:nomis_offender_id)
    @early_allocations = preload_early_allocations(offender_nos)

    allocations.map { |allocation|
      # TODO: Replace this with a call to OffenderService.get_multiple_offenders_as_hash
      # earlier in the method so that we can look up the offender from a local
      # hash so that we are not doing N+1 API calls.
      offender = OffenderService.get_offender(allocation.nomis_offender_id)

      prd_task = parole_review_date_task(offender)
      next prd_task if prd_task.present?

      delius_task = missing_info_task(offender)
      next delius_task if delius_task.present?

      early_task = early_allocation_update_task(offender)
      next early_task if early_task.present?
    }.compact
  end

  def parole_review_date_task(offender)
    # Offender is indeterminate and their parole review date is old or missing
    return unless offender.indeterminate_sentence?

    if offender.parole_review_date.blank? || offender.parole_review_date < Time.zone.today
      PomTaskPresenter.new.tap { |presenter|
        presenter.offender = offender
        presenter.action_label = 'Parole review date'
        presenter.action_url = prison_edit_prd_path(active_prison, offender.offender_no)
      }
    end
  end

  def missing_info_task(offender)
    # Offender had their delius data manually added and as a result are missing
    # new key fields.
    if offender.mappa_level.blank? || offender.ldu.blank?
      PomTaskPresenter.new.tap { |presenter|
        presenter.offender = offender
        presenter.action_label = 'nDelius case matching'
        presenter.action_url = prison_case_information_path(active_prison, offender.offender_no)
      }
    end
  end

  def early_allocation_update_task(offender)
    # An early allocation request has been made but is pending a response from
    # the community, and therefore needs updating.
    if @early_allocations.key?(offender.offender_no)
      PomTaskPresenter.new.tap { |presenter|
        presenter.offender = offender
        presenter.action_label = 'Early allocation decision'
        presenter.action_url = community_decision_prison_prisoner_early_allocation_path(
          active_prison, offender.offender_no)
      }
    end
  end

  def caseload
    @caseload ||= PrisonOffenderManagerService.get_allocated_offenders(
      @pom.staff_id, active_prison
    )
  end

  def preload_early_allocations(offender_nos)
    # For the provided offender numbers, determines whether they have an outstanding
    # early allocation and then adds them to a hash for quick lookup.  If a specific
    # offender does have an outstanding early allocation their offender number will
    # appear as a key (with a boolean value). We do this because hash lookup is
    # significantly faster than array/list lookup.
    EarlyAllocation.where(nomis_offender_id: offender_nos).map { |early_allocation|
      if early_allocation.discretionary? && early_allocation.community_decision.nil?
        [early_allocation.nomis_offender_id, true]
      end
    }.compact.to_h
  end

  def ensure_pom
    @pom = PrisonOffenderManagerService.get_signed_in_pom_details(
      current_user,
      active_prison
    )

    if @pom.blank?
      redirect_to '/'
    end
  end
end
