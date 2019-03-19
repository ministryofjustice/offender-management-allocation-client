class PrisonOffenderManagerService
  def self.get_pom_detail(nomis_staff_id)
    PomDetail.find_or_create_by!(nomis_staff_id: nomis_staff_id.to_i) { |s|
      s.working_pattern = s.working_pattern || 0.0
      s.status = s.status || 'active'
    }
  end

  def self.get_poms(prison)
    poms = Nomis::Elite2::PrisonOffenderManagerApi.list(prison)

    poms = poms.map { |pom|
      detail = get_pom_detail(pom.staff_id)
      pom.add_detail(detail)
      pom
    }.compact

    poms = poms.select { |pom| yield pom } if block_given?

    poms
  end

  def self.get_pom(caseload, nomis_staff_id)
    poms_list = get_poms(caseload)
    @pom = poms_list.select { |p| p.staff_id == nomis_staff_id.to_i }.first
    @pom.emails = Nomis::Elite2::PrisonOffenderManagerApi.
        fetch_email_addresses(@pom.staff_id)
    @pom
  end

  def self.get_pom_names(prison)
    poms_list = get_poms(prison)
    poms_list.each_with_object({}) { |p, hsh|
      hsh[p.staff_id] = p.full_name
    }
  end

  def self.get_allocations_for_pom(nomis_staff_id, prison)
    detail = get_pom_detail(nomis_staff_id)
    detail.allocations.where(active: true, prison: prison)
  end

  # rubocop:disable Metrics/MethodLength
  def self.get_allocated_offenders(nomis_staff_id, prison)
    allocation_list = get_allocations_for_pom(nomis_staff_id, prison)

    offender_ids = allocation_list.map(&:nomis_offender_id)

    allocation_list_with_responsibility = allocation_list.map { |alloc|
      offender = OffenderService.get_offender(alloc.nomis_offender_id)
      alloc.responsibility =
        ResponsibilityService.new.calculate_pom_responsibility(offender)
      alloc
    }

    offender_map = OffenderService.get_sentence_details(offender_ids)

    allocations_and_offender = []
    allocation_list_with_responsibility.each do |alloc|
      allocations_and_offender << [alloc, offender_map[alloc.nomis_offender_id]]
    end

    allocations_and_offender
  end
  # rubocop:enable Metrics/MethodLength

  def self.get_new_cases(nomis_staff_id, prison)
    allocations = get_allocated_offenders(nomis_staff_id, prison)
    allocations.select { |allocation, _offender| allocation.created_at >= 7.days.ago }
  end

  def self.get_signed_in_pom_details(current_user)
    user = Nomis::Custody::UserApi.user_details(current_user)

    poms_list = get_poms(user.active_nomis_caseload)
    @pom = poms_list.select { |p| p.staff_id.to_i == user.staff_id.to_i }.first
  end

  def self.update_pom(params)
    pom = PomDetail.where(nomis_staff_id: params[:nomis_staff_id]).first
    pom.working_pattern = params[:working_pattern] || pom.working_pattern
    pom.status = params[:status] || pom.status
    pom.save!
    AllocationService.deallocate_pom(params[:nomis_staff_id]) if pom.status == 'inactive'
    pom
  end
end
