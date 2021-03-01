# frozen_string_literal: true

module HmppsApi
  class SentenceDetail
    include Deserialisable

    # Note - this is hiding a defect - we never get sentence_expiry_date from NOMIS (maybe we should?)
    attr_accessor :sentence_expiry_date

    def automatic_release_date
      automatic_release_override_date.presence || nomis_automatic_release_date
    end

    def conditional_release_date
      conditional_release_override_date.presence || nomis_conditional_release_date
    end

    def post_recall_release_date
      post_recall_release_date = nomis_post_recall_release_date

      return post_recall_release_date if actual_parole_date.blank?

      return actual_parole_date if post_recall_release_date.blank?

      if actual_parole_date.before?(post_recall_release_date)
        actual_parole_date
      else
        post_recall_release_date
      end
    end

    def earliest_release_date
      dates = [
        automatic_release_date,
        conditional_release_date,
        home_detention_curfew_actual_date,
        home_detention_curfew_eligibility_date,
        parole_eligibility_date,
        tariff_date
      ].compact

      if dates.empty?
        dates = [
          sentence_expiry_date,
          licence_expiry_date,
          post_recall_release_date,
          actual_parole_date].compact
      end

      past_dates, future_dates = dates.partition { |date| date < Time.zone.today }

      future_dates.any? ? future_dates.min.to_date : past_dates.max.try(:to_date)
    end

    def self.from_json(payload)
      SentenceDetail.new(payload)
    end

    def initialize(payload)
      @payload = payload
    end

    def home_detention_curfew_eligibility_date
      @home_detention_curfew_eligibility_date ||= deserialise_date(@payload, 'homeDetentionCurfewEligibilityDate')
    end

    def home_detention_curfew_actual_date
      @home_detention_curfew_actual_date ||= deserialise_date(@payload, 'homeDetentionCurfewActualDate')
    end

    def parole_eligibility_date
      @parole_eligibility_date ||= deserialise_date(@payload, 'paroleEligibilityDate')
    end

    def release_date
      @release_date ||= deserialise_date(@payload, 'releaseDate')
    end

    def licence_expiry_date
      @licence_expiry_date ||= deserialise_date(@payload, 'licenceExpiryDate')
    end

    def sentence_start_date
      @sentence_start_date ||= deserialise_date(@payload, 'sentenceStartDate')
    end

    def tariff_date
      @tariff_date ||= deserialise_date(@payload, 'tariffDate')
    end

    def actual_parole_date
      @actual_parole_date ||= deserialise_date(@payload, 'actualParoleDate')
    end

    # This has a test, but shouldn't be public - no-one uses it apart from the test
    def nomis_post_recall_release_date
      parsed_nomis_post_recall_release_override_date.presence || parsed_nomis_post_recall_release_date
    end

  private

    def nomis_automatic_release_date
      @nomis_automatic_release_date ||= deserialise_date(@payload, 'automaticReleaseDate')
    end

    def automatic_release_override_date
      @automatic_release_override_date ||= deserialise_date(@payload, 'automaticReleaseOverrideDate')
    end

    def nomis_conditional_release_date
      @nomis_conditional_release_date ||= deserialise_date(@payload, 'conditionalReleaseDate')
    end

    def conditional_release_override_date
      @conditional_release_override_date ||= deserialise_date(@payload, 'conditionalReleaseOverrideDate')
    end

    def parsed_nomis_post_recall_release_override_date
      @parsed_nomis_post_recall_release_override_date ||= deserialise_date(@payload, 'postRecallReleaseOverrideDate')
    end

    def parsed_nomis_post_recall_release_date
      @parsed_nomis_post_recall_release_date ||= deserialise_date(@payload, 'postRecallReleaseDate')
    end
  end
end
