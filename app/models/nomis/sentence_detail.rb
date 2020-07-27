# frozen_string_literal: true

module Nomis
  class SentenceDetail
    include Deserialisable

    attr_reader :home_detention_curfew_eligibility_date,
                :home_detention_curfew_actual_date,
                :parole_eligibility_date,
                :licence_expiry_date,
                :sentence_start_date,
                :tariff_date,
                :sentence_expiry_date,
                :actual_parole_date

    def initialize(fields = {})
      fields.each do |k, v|
        instance_variable_set("@#{k}", v)
      end
    end

    def automatic_release_date
      @automatic_release_override_date.presence || @automatic_release_date
    end

    def conditional_release_date
      @conditional_release_override_date.presence || @conditional_release_date
    end

    def post_recall_release_date
      post_recall_release_date = nomis_post_recall_release_date

      return post_recall_release_date if @actual_parole_date.blank?

      return @actual_parole_date if post_recall_release_date.blank?

      if @actual_parole_date.before?(post_recall_release_date)
        @actual_parole_date
      else
        post_recall_release_date
      end
    end

    def nomis_post_recall_release_date
      @nomis_post_recall_release_override_date.presence || @nomis_post_recall_release_date
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
      SentenceDetail.new.tap { |obj|
        obj.load_from_json(payload)
      }
    end

    def load_from_json(payload)
      @parole_eligibility_date = deserialise_date(payload, 'paroleEligibilityDate')
      @sentence_start_date = deserialise_date(payload, 'sentenceStartDate')
      @tariff_date = deserialise_date(payload, 'tariffDate')
      @automatic_release_date = deserialise_date(payload, 'automaticReleaseDate')
      @nomis_post_recall_release_date = deserialise_date(payload, 'postRecallReleaseDate')
      @nomis_post_recall_release_override_date = deserialise_date(payload, 'postRecallReleaseOverrideDate')

      @conditional_release_date = deserialise_date(
        payload, 'conditionalReleaseDate'
      )
      @automatic_release_override_date = deserialise_date(
        payload, 'automaticReleaseOverrideDate'
      )
      @home_detention_curfew_eligibility_date = deserialise_date(
        payload, 'homeDetentionCurfewEligibilityDate'
      )
      @home_detention_curfew_actual_date = deserialise_date(
        payload, 'homeDetentionCurfewActualDate'
      )
      @conditional_release_override_date = deserialise_date(
        payload, 'conditionalReleaseOverrideDate'
      )
      @actual_parole_date = deserialise_date(payload, 'actualParoleDate')
      @licence_expiry_date = deserialise_date(payload, 'licenceExpiryDate')
    end
  end
end
