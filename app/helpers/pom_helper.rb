# frozen_string_literal: true

module PomHelper
  def format_working_pattern(pattern)
    if pattern == 1.0
      'Full time'
    else
      "Part time - #{pattern}"
    end
  end

  def working_pattern_to_days(pattern)
    ['',
     'half a day',
     'one day',
     'one and a half days',
     'two days',
     'two and a half days',
     'three days',
     'three and a half days',
     'four days',
     'four and a half days'
    ][pattern]
  end

  def full_name(pom)
    "#{pom.last_name}, #{pom.first_name}".titleize
  end

  def full_name_ordered(pom)
    "#{pom.first_name} #{pom.last_name}".titleize
  end

  def grade(pom)
    "#{pom.position_description.split(' ').first} POM"
  end

  def fetch_pom_name(staff_id)
    pom_firstname, pom_secondname =
      PrisonOffenderManagerService.get_pom_name(staff_id)
    "#{pom_secondname}, #{pom_firstname}"
  end
end
