module BadgeHelper
  def badge_colour(offender)
    if offender.indeterminate_sentence?
      'purple'
    else
      'blue'
    end
  end

  def badge_text(offender)
    if offender.indeterminate_sentence?
      'Indeterminate'
    else
      'Determinate'
    end
  end

  def badge_for_parole?(offender)
    offender.tariff_date.present? || offender.parole_eligibility_date.present? || parole_review_date?(offender)
  end

  def parole_review_date?(offender)
    offender.indeterminate_sentence? && offender.parole_review_date.present?
  end
end
