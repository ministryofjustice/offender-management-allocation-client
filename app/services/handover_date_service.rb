# frozen_string_literal: true

class HandoverDateService
  def self.handover_start_date(offender)
    return [nil, 'No earliest release date'] if offender.earliest_release_date.nil?

    if offender.nps_case?
      if offender.early_allocation?
        [early_allocation_handover_date(offender), 'Early Allocation']
      elsif offender.indeterminate_sentence?
        [offender.earliest_release_date - 8.months, 'NPS Indeterminate']
      else
        [offender.earliest_release_date - (7.months + 15.days), 'NPS Determinate']
      end
    else
      [nil, 'CRC Case']
    end
  end

  def self.responsibility_handover_date(offender)
    if offender.earliest_release_date.nil?
      [nil, 'No earliest release date']
    elsif offender.nps_case?
      nps_handover_date(offender)
    else
      [crc_handover_date(offender), 'CRC']
    end
  end

private

  def self.crc_handover_date(offender)
    [
        offender.home_detention_curfew_eligibility_date,
        offender.conditional_release_date
    ].compact.map { |date| date - 12.weeks }.min
  end

  def self.nps_handover_date(offender)
    if offender.early_allocation?
      return [early_allocation_handover_date(offender), 'NPS Early']
    end

    if offender.indeterminate_sentence?
      [indeterminate_responsibility_date(offender), 'NPS Inderminate']
    elsif offender.parole_eligibility_date.present?
      [offender.parole_eligibility_date - 8.months, 'NPS Determinate Parole Case']
    elsif offender.mappa_level.blank?
      [mappa1_responsibility_date(offender), 'NPS - MAPPA level unknown']
    elsif offender.mappa_level.in? [1, 0]
      [mappa1_responsibility_date(offender), 'NPS Determinate Mappa 1/N']
    else
      [mappa_23_responsibility_date(offender), 'NPS Determinate Mappa 2/3']
    end
  end

  def self.indeterminate_responsibility_date(offender)
    [
        offender.parole_eligibility_date,
        offender.tariff_date
    ].compact.map { |date| date - 8.months }.min
  end

  # There are a couple of places where we need .5 of a month - which
  # we have assumed 15.days is a reasonable compromise implementation
  def self.mappa_23_responsibility_date(offender)
    [
        offender.conditional_release_date,
        offender.automatic_release_date
    ].compact.map { |date| date - (7.months + 15.days) }.min
  end

  def self.mappa1_responsibility_date(offender)
    crd_ard = [
        offender.conditional_release_date,
        offender.automatic_release_date
    ].compact.map { |date| date - (4.months + 15.days) }.min

    [
        crd_ard,
        offender.home_detention_curfew_eligibility_date
    ].compact.min
  end

  def self.early_allocation_handover_date(offender)
    [
        offender.conditional_release_date,
        offender.automatic_release_date
    ].compact.map { |date| date - 15.months }.min
  end
end
