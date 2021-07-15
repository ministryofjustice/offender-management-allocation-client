# frozen_string_literal: true

class AllocationHistory < ApplicationRecord
  self.table_name = 'allocation_history'

  has_paper_trail

  ALLOCATE_PRIMARY_POM = 0
  REALLOCATE_PRIMARY_POM = 1
  ALLOCATE_SECONDARY_POM = 2
  REALLOCATE_SECONDARY_POM = 3
  DEALLOCATE_PRIMARY_POM = 4
  DEALLOCATE_SECONDARY_POM = 5
  DEALLOCATE_RELEASED_OFFENDER = 6

  USER = 0
  OFFENDER_TRANSFERRED = 1
  OFFENDER_RELEASED = 2

  after_commit :push_pom_to_community_api

  # When adding a new 'event' or 'event trigger'
  # make sure the constant it points to
  # has a value that is sequential and does not
  # re-assign an already existing value
  enum event: {
    allocate_primary_pom: ALLOCATE_PRIMARY_POM,
    reallocate_primary_pom: REALLOCATE_PRIMARY_POM,
    allocate_secondary_pom: ALLOCATE_SECONDARY_POM,
    reallocate_secondary_pom: REALLOCATE_SECONDARY_POM,
    deallocate_primary_pom: DEALLOCATE_PRIMARY_POM,
    deallocate_secondary_pom: DEALLOCATE_SECONDARY_POM,
    deallocate_released_offender: DEALLOCATE_RELEASED_OFFENDER
  }

  # 'Event triggers' capture the subject or action that triggered the event
  enum event_trigger: {
    user: USER,
    offender_transferred: OFFENDER_TRANSFERRED,
    offender_released: OFFENDER_RELEASED
  }

  scope :active_pom_allocations, lambda { |nomis_staff_id, prison|
    secondaries = where(secondary_pom_nomis_id: nomis_staff_id)

    where(primary_pom_nomis_id: nomis_staff_id).or(secondaries).where(prison: prison)
  }

  scope  :active_allocations_for_prison, lambda { |prison| where.not(primary_pom_nomis_id: nil).where(prison: prison) }

  scope :for_pom, lambda { |nomis_staff_id|
    secondaries = where(secondary_pom_nomis_id: nomis_staff_id)

    where(primary_pom_nomis_id: nomis_staff_id).or(secondaries)
  }

  validate do |av|
    if av.primary_pom_nomis_id.present? &&
      av.primary_pom_nomis_id == av.secondary_pom_nomis_id
      errors.add(:primary_pom_nomis_id,
                 'Primary POM cannot be the same as co-working POM')
    end
  end

  # find all allocations which cannot be handed over as there is no LDU email address
  def self.without_ldu_emails
    blank_ldu_cases = CaseInformation.where(local_delivery_unit: nil)
    offenders = blank_ldu_cases.nps.pluck(:nomis_offender_id)
    AllocationHistory.where(nomis_offender_id: offenders)
  end

  def active?
    primary_pom_nomis_id.present?
  end

  def override_reasons
    JSON.parse(self[:override_reasons]) if self[:override_reasons].present?
  end

  def get_old_versions
    versions.map(&:reify).compact
  end

  def previously_allocated_poms
    get_old_versions.map { |h| [h.primary_pom_nomis_id, h.secondary_pom_nomis_id] }.flatten.compact.uniq
  end

  # note: this creates an allocation where the co-working POM is set, but the primary
  # one is not. It should still show up in the 'waiting to allocate' bucket.
  # This appears to be safe as allocations only show up for viewing if they have
  # a non-nil primary_pom_nomis_id
  def self.deallocate_primary_pom(nomis_staff_id, prison)
    active_pom_allocations(nomis_staff_id, prison).each do |alloc|
      alloc.primary_pom_nomis_id = nil
      alloc.primary_pom_name = nil
      alloc.recommended_pom_type = nil
      alloc.primary_pom_allocated_at = nil
      alloc.event = DEALLOCATE_PRIMARY_POM
      alloc.event_trigger = USER

      alloc.save!
    end
  end

  def self.deallocate_secondary_pom(nomis_staff_id, prison)
    active_pom_allocations(nomis_staff_id, prison).each do |alloc|
      alloc.secondary_pom_nomis_id = nil
      alloc.secondary_pom_name = nil
      alloc.event = DEALLOCATE_SECONDARY_POM
      alloc.event_trigger = USER

      alloc.save!
    end
  end

  validates :nomis_offender_id,
            :allocated_at_tier,
            :event,
            :event_trigger,
            :prison, presence: true

  def deallocate_offender_after_release
    deallocate_offender event: AllocationHistory::DEALLOCATE_RELEASED_OFFENDER, event_trigger: AllocationHistory::OFFENDER_RELEASED if active?
  end

  def dealloate_offender_after_transfer
    deallocate_offender event: AllocationHistory::DEALLOCATE_PRIMARY_POM, event_trigger: AllocationHistory::OFFENDER_TRANSFERRED if active?
  end

  # check for changes in the last week where the target value
  # (item[1] in the array) is our staff_id
  def new_case_for? staff_id
    versions.where('created_at >= ?', 7.days.ago).map { |c|
      YAML.load(c.object_changes)
    }.select { |c|
      c.key?('primary_pom_nomis_id') && c['primary_pom_nomis_id'][1] == staff_id ||
        c.key?('secondary_pom_nomis_id') && c['secondary_pom_nomis_id'][1] == staff_id
    }.any?
  end

private

  def deallocate_offender event:, event_trigger:
    primary_pom = HmppsApi::PrisonApi::PrisonOffenderManagerApi.staff_detail(primary_pom_nomis_id)
    offender = OffenderService.get_offender(nomis_offender_id)
    mail_params = {
        email: primary_pom.email_address,
        pom_name: primary_pom.first_name.titleize,
        offender_name: offender.full_name,
        nomis_offender_id: nomis_offender_id,
        prison_name: Prison.find(prison).name,
        url: Rails.application.routes.default_url_options[:host] +
            Rails.application.routes.url_helpers.prison_staff_caseload_path(prison, primary_pom_nomis_id)
    }
    update!(
      event: event,
      event_trigger: event_trigger,
      primary_pom_nomis_id: nil,
      primary_pom_name: nil,
      primary_pom_allocated_at: nil,
      secondary_pom_nomis_id: nil,
      secondary_pom_name: nil,
      recommended_pom_type: nil,
    )

    PomMailer.offender_deallocated(mail_params).deliver_later
  end

  def push_pom_to_community_api
    if saved_change_to_primary_pom_nomis_id?
      PushPomToDeliusJob.perform_later(self)
    end
  end
end
