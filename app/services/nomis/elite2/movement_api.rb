# frozen_string_literal: true

module Nomis
  module Elite2
    class MovementApi
      extend Elite2Api

      def self.movements_on_date(date)
        route = '/elite2api/api/movements'

        data = e2_client.get(route, queryparams: {
                               movementDate: date.strftime('%F'),
                               fromDateTime: (date - 1.day).strftime('%FT%R')
                             })
        data.map { |movement|
          api_deserialiser.deserialise(Nomis::Movement, movement)
        }
      end

      # rubocop:disable Metrics/LineLength
      def self.movements_for(offender_no)
        route = '/elite2api/api/movements/offenders?movementTypes=ADM&movementTypes=TRN&movementTypes=REL&latestOnly=false'

        if offender_no.is_a?(Array)
          data = e2_client.post(route, offender_no)
        else
          data = e2_client.post(route, [offender_no])
        end

        data.sort_by { |k| k['createDateTime'] }.map{ |movement|
          api_deserialiser.deserialise(Nomis::Movement, movement)
        }
      end
      # rubocop:enable Metrics/LineLength
    end
  end
end
