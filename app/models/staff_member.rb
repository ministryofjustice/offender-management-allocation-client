# frozen_string_literal: true

# This object represents a staff member who may or my not be a POM. It is up to the caller to check
# and do something interesting if they are not a POM at a specific prison.
class StaffMember
  # maybe this method shouldn't be here?
  attr_reader :staff_id
  delegate :position_description, :probation_officer?, :prison_officer?, to: :pom
  delegate :working_pattern, :status, to: :@pom_detail

  def initialize(prison, staff_id, pom_detail = default_pom_detail(prison.code, staff_id))
    @prison = prison
    @staff_id = staff_id.to_i
    @pom_detail = pom_detail
  end

  def full_name
    "#{last_name}, #{first_name}"
  end

  def first_name
    staff_detail.first_name&.titleize
  end

  def last_name
    staff_detail.last_name&.titleize
  end

  def email_address
    @email_address ||= HmppsApi::PrisonApi::PrisonOffenderManagerApi.fetch_email_addresses(@staff_id).first
  end

  def has_pom_role?
    pom.present?
  end

  def active?
    status == 'active'
  end

  def position
    if pom.present?
      pom.position
    else
      'STAFF'
    end
  end

  def allocations
    @allocations ||= fetch_allocations
  end

private

  def pom
    @pom ||= fetch_pom
  end

  def fetch_pom
    poms = HmppsApi::PrisonApi::PrisonOffenderManagerApi.list(@prison.code)
    poms.detect { |pom| pom.staff_id == @staff_id }
  end

  def fetch_allocations
    offender_hash = @prison.offenders.index_by(&:offender_no)
    allocations = Allocation.
        where(nomis_offender_id: offender_hash.keys).
        active_pom_allocations(@staff_id, @prison.code)
    allocations.map { |alloc|
      AllocatedOffender.new(@staff_id, alloc, offender_hash.fetch(alloc.nomis_offender_id))
    }
  end

  # Attempt to forward-populate the PomDetail table for new records
  def default_pom_detail(prison_code, staff_id)
    @pom_detail = PomDetail.find_or_create_by!(prison_code: prison_code, nomis_staff_id: staff_id) { |pom|
      pom.prison_code = prison_code
      pom.working_pattern = 0.0
      pom.status = 'active'
    }
  end

  def staff_detail
    @staff_detail ||= HmppsApi::PrisonApi::PrisonOffenderManagerApi.staff_detail(@staff_id)
  end
end
