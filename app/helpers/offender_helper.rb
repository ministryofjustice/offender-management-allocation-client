module OffenderHelper
  def digital_prison_service_profile_path(offender_id)
    URI.join(
      Rails.configuration.digital_prison_service_host,
      "/offenders/#{offender_id}/quick-look"
    ).to_s
  end

  def pom_responsibility_label(offender)
    if offender.pom_responsible?
      'Responsible'
    elsif offender.pom_supporting?
      'Supporting'
    else
      'Co-working'
    end
  end

  def case_owner_label(offender)
    if offender.pom_responsible?
      'Custody'
    elsif offender.pom_supporting?
      'Community'
    else
      'Unknown'
    end
  end

  def last_event(allocation)
    event = event_type(allocation.event)
    event + ' - ' + allocation.created_at.strftime('%d/%m/%Y')
  end

  def event_type(event)
    type = (event.include? 'primary_pom') ? 'POM ' : 'Co-working POM '

    if event.include? 'reallocate'
      # POM-778 Just not covered by tests
      #:nocov:
      type + 're-allocated'
      #:nocov:
    elsif event.include? 'deallocate'
      type + 'removed'
    elsif event.include? 'allocate'
      type + 'allocated'
    end
  end

  def recommended_pom_type_label offender
    if RecommendationService.recommended_pom_type(offender) == RecommendationService::PRISON_POM
      'Prison officer'
    else
      'Probation officer'
    end
  end

  def non_recommended_pom_type_label offender
    if RecommendationService.recommended_pom_type(offender) == RecommendationService::PRISON_POM
      'Probation officer'
    else
      'Prison officer'
    end
  end

  def complex_reason_label offender
    if RecommendationService.recommended_pom_type(offender) == RecommendationService::PRISON_POM
      'Prisoner assessed as not suitable for a prison officer POM'
    else
      'Prisoner assessed as suitable for a prison officer POM despite tiering calculation'
    end
  end

  def tier_a_case_count offenders
    offenders.count { |a| a.tier == 'A' }
  end

  def tier_b_case_count offenders
    offenders.count { |a| a.tier == 'B' }
  end

  def tier_c_case_count offenders
    offenders.count { |a| a.tier == 'C' }
  end

  def tier_d_case_count offenders
    offenders.count { |a| a.tier == 'D' }
  end

  # :nocov: new case mix bar doesn't include tier N/A cases :-(
  def no_tier_case_count offenders
    offenders.count { |a| a.tier == 'N/A' }
  end
  # :nocov:

  def probation_field offender, field
    offender.public_send field if offender.probation_record.present?
  end
end
