module Nomis
  class OffenderBase
    delegate :home_detention_curfew_eligibility_date,
             :home_detention_curfew_actual_date,
             :conditional_release_date,
             :parole_eligibility_date, :tariff_date,
             :automatic_release_date, :licence_expiry_date,
             :post_recall_release_date, :earliest_release_date,
             to: :sentence

    attr_accessor :category_code, :date_of_birth

    attr_reader :first_name, :last_name, :booking_id,
                :offender_no, :convicted_status

    attr_accessor :sentence, :allocated_pom_name, :allocated_com_name, :case_allocation, :mappa_level, :tier

    attr_reader :crn,
                :welsh_offender, :parole_review_date,
                :ldu, :team

    def convicted?
      convicted_status == 'Convicted'
    end

    def sentenced?
      return false if sentence&.sentence_start_date.blank?

      has_determinate_dates? || has_indeterminate_dates? || has_recall_dates?
    end

    def early_allocation?
      @early_allocation
    end

    def nps_case?
      case_allocation == 'NPS'
    end

    def sentence_type_code
      @sentence_type.code
    end

    # sentence type may be nil if we are created as a stub
    def recalled?
      @sentence_type.try(:recall_sentence?)
    end

    def indeterminate_sentence?
      @sentence_type.try(:indeterminate_sentence?)
    end

    def criminal_sentence?
      @sentence_type.civil? == false
    end

    def civil_sentence?
      @sentence_type.civil?
    end

    def describe_sentence
      @sentence_type.description
    end

    def over_18?
      age >= 18
    end

    def immigration_case?
      sentence_type_code == 'DET'
    end

    def pom_responsibility
      @pom_responsibility ||= ResponsibilityService.calculate_pom_responsibility(self)
    end

    def sentence_start_date
      sentence.sentence_start_date
    end

    def full_name
      "#{last_name}, #{first_name}".titleize
    end

    def full_name_ordered
      "#{first_name} #{last_name}".titleize
    end

    def age
      return nil if date_of_birth.blank?

      now = Time.zone.now

      if now.month == date_of_birth.month
        birthday_passed = now.day >= date_of_birth.day
      elsif now.month > date_of_birth.month
        birthday_passed = true
      end

      birth_years_ago = now.year - date_of_birth.year

      @age ||= birthday_passed ? birth_years_ago : birth_years_ago - 1
    end

    def load_from_json(payload)
      # It is expected that this method will be called by the subclass which
      # will have been given a payload at the class level, and will call this
      # method from it's own internal from_json
      @first_name = payload['firstName']
      @last_name = payload['lastName']
      @offender_no = payload.fetch('offenderNo')
      @convicted_status = payload['convictedStatus']
      @sentence_type = SentenceType.new(payload['imprisonmentStatus'])
      @category_code = payload['categoryCode']
      @date_of_birth = deserialise_date(payload, 'dateOfBirth')
      @early_allocation = false
    end

    def inprisonment_status=(status)
      @sentence_type = SentenceType.new(status)
    end

    def handover_start_date
      handover.start_date
    end

    def handover_reason
      handover.reason
    end

    def responsibility_handover_date
      handover.handover_date
    end

    def load_case_information(record)
      return if record.blank?

      @tier = record.tier
      @case_allocation = record.case_allocation
      @welsh_offender = record.welsh_offender == 'Yes'
      @crn = record.crn
      @mappa_level = record.mappa_level
      @ldu = record.local_divisional_unit
      @team = record.team.try(:name)
      @parole_review_date = record.parole_review_date
      @early_allocation = record.latest_early_allocation.present? &&
        (record.latest_early_allocation.eligible? || record.latest_early_allocation.community_decision?)
    end

  private

    def handover
      @handover ||= if pom_responsibility&.custody?
                      HandoverDateService.handover(self)
                    else
                      HandoverDateService::NO_HANDOVER_DATE
                    end
    end

    def has_determinate_dates?
      !indeterminate_sentence? &&
        (sentence.conditional_release_date.present? ||
        sentence.automatic_release_date.present? ||
        sentence.home_detention_curfew_actual_date.present? ||
        sentence.home_detention_curfew_eligibility_date.present? ||
        sentence.parole_eligibility_date.present?)
    end

    def has_indeterminate_dates?
      indeterminate_sentence? &&
        sentence.tariff_date.present? ||
        sentence.parole_eligibility_date.present?
    end

    def has_recall_dates?
      recalled? &&
        sentence.post_recall_release_date.present? ||
        sentence.licence_expiry_date.present?
    end
  end
end
