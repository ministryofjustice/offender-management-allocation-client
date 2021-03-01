# frozen_string_literal: true

module ApplicationHelper
  def format_date(date_obj, replacement: '')
    return replacement if date_obj.nil?

    date_obj.strftime('%d/%m/%Y')
  end

  def format_date_long(date_obj)
    date_obj.strftime("#{date_obj.day.ordinalize} %B %Y") +
        ' (' + date_obj.strftime('%R') + ')'
  end

  def pom_level(level)
    {
      'PO' => 'Probation POM',
      'PRO' => 'Prison POM',
      'STAFF' => 'N/A'
    }.fetch(level)
  end

  def override_reason_contains(override, val)
    override.override_reasons.present? && override.override_reasons.include?(val)
  end

  def service_provider_label(provider)
    {
      'CRC' => 'Community Rehabilitation Company (CRC)',
      'NPS' => 'National Probation Service (NPS)'
    }[provider]
  end

  def working_pattern_name(pattern)
    return 'Full time' if pattern.to_f == 1.0

    'Part time'
  end

  def sentence_type_label(offender)
    return 'Indeterminate' if offender.indeterminate_sentence?

    'Determinate'
  end

  def humanized_bool(bool_value)
    bool_value ? 'Yes' : 'No'
  end

  def auto_delius_import_enabled?(prison)
    Flipflop.auto_delius_import? ||
      (ENV['AUTO_DELIUS_IMPORT'] || '').split(',').include?(prison)
  end

  def format_email(email)
    if email.nil?
      '(email address not found)'
    else
      mail_to(email)
    end
  end
end
