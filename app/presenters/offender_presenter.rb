# frozen_string_literal: true

class OffenderPresenter
  attr_reader :offender, :responsibility

  delegate :offender_no, :first_name, :last_name, :booking_id,
           :indeterminate_sentence?, :sentence_type_code, :describe_sentence,
           :full_name_ordered, :full_name, :main_offence,
           :sentence_start_date, :team, :prison_id,
           :home_detention_curfew_eligibility_date, :home_detention_curfew_actual_date,
           :tariff_date, :date_of_birth, :parole_eligibility_date,
           :welsh_offender, :case_allocation, :earliest_release_date,
           :category_code, :conditional_release_date, :automatic_release_date,
           :awaiting_allocation_for, :allocated_pom_name, :allocation_date, :allocated_com_name,
           :tier, :parole_review_date, :crn, :convicted_status, :convicted?, :ldu,
           :handover_start_date, :responsibility_handover_date, :handover_reason, :prison_arrival_date,
           :licence_expiry_date, :post_recall_release_date,
           :over_18?, :recalled?, :sentenced?, :immigration_case?, :mappa_level, to: :@offender

  def initialize(offender, responsibility)
    @offender = offender
    @responsibility = responsibility
  end

  def pom_responsibility
    # If this presenter was provided with a responsibility object from
    # a responsibility override, we will return that, falling back on
    # asking the offender class to calculate it.
    if @responsibility
      if @responsibility.value == Responsibility::PRISON
        ResponsibilityService::RESPONSIBLE
      else
        ResponsibilityService::SUPPORTING
      end
    else
      @offender.pom_responsibility
    end
  end

  def recommended_pom_type_label
    rec_type = RecommendationService.recommended_pom_type(@offender)

    if rec_type == RecommendationService::PRISON_POM
      'Prison officer'
    else
      'Probation officer'
    end
  end

  def recommended_pom_type
    @recommended_pom_type ||= RecommendationService.recommended_pom_type(@offender)
  end

  def non_recommended_pom_type_label
    if recommended_pom_type == RecommendationService::PRISON_POM
      'Probation officer'
    else
      'Prison officer'
    end
  end

  def complex_reason_label
    if recommended_pom_type == RecommendationService::PRISON_POM
      'Prisoner assessed as not suitable for a prison officer POM'
    else
      'Prisoner assessed as suitable for a prison officer POM despite tiering calculation'
    end
  end
end
