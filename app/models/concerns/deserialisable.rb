# This module provides a helper for deserialising dates from a payload
# provided from one of the API calls.  We need this to be available at
# class and instance level, hence the two definitions.
module Deserialisable
  include ActiveSupport::Concern

  def self.included(base)
    def base.deserialise_date(payload, field)
      value = payload[field]
      # This is 3x faster than Date.parse - we know the format is YYYY-MM-DD
      #Date.strptime(value,"%Y-%m-%d") if value
      # This is slightly faster still at the expense of readability...
      if value
        year, month, day = value.split('-').map(&:to_i)
        Date.new(year, month, day)
      end
    end
  end

  def deserialise_date(payload, field)
    self.class.deserialise_date(payload, field)
  end
end
