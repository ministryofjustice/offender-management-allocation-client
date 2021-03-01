# frozen_string_literal: true

module HmppsApi
  module PrisonApi
    class MovementApi
      extend PrisonApiClient

      def self.movements_on_date(date)
        route = '/movements'

        # the 'fromDateTime' field in the API is the 'earliest creation date' of a movement
        # obviously we have no idea how early this might be, so set it to last year so that they
        # are hopefully all caught.
        data = client.get(route, queryparams: {
                               movementDate: date.strftime('%F'),
                               fromDateTime: (date - 1.year).strftime('%FT%R')
                             })
        data.map { |movement|
          HmppsApi::Movement.from_json(movement)
        }
      end

      def self.movements_for(offender_no)
        route = '/movements/offenders'

        data = client.post(route, [offender_no],
                           queryparams: { latestOnly: false, movementTypes: %w[ADM TRN REL] },
                           cache: true)
        data.sort_by { |k| k['movementDate'] }.map { |movement|
          HmppsApi::Movement.from_json(movement)
        }
      end

      def self.admissions_for(offender_nos)
        # admissions need to include transfers from one place to another
        route = '/movements/offenders'
        types = [HmppsApi::MovementType::ADMISSION,
                 HmppsApi::MovementType::TRANSFER].freeze

        data = client.post(route, offender_nos,
                           queryparams: { latestOnly: false, movementTypes: types },
                           cache: true)
                     .group_by { |x| x['offenderNo'] }.values

        movements = data.map { |d|
          d.sort_by { |k| k['movementDate'] }.map { |movement|
            HmppsApi::Movement.from_json(movement)
          }
        }
        # return a hash of offender_no => [HmppsApi::Movement]
        movements.index_by { |m| m.first.offender_no }
      end

      def self.latest_temp_movement_for(offender_nos)
        route = '/movements/offenders'
        types = [HmppsApi::MovementType::ADMISSION,
                 HmppsApi::MovementType::TRANSFER,
                 HmppsApi::MovementType::TEMPORARY].freeze

        # 'data' is an array of arrays, with one array for each offenderNo
        data = client.post(route, offender_nos,
                           queryparams: { latestOnly: true, movementTypes: types },
                           cache: true)
                     .group_by { |x| x['offenderNo'] }.values

        # This reduces the data to the most recent per offender
        # (one array rather than an array of arrays)
        movements = data.map { |d|
          movement = d.max_by { |k| k['movementDate'] }
          HmppsApi::Movement.from_json(movement)
        }
        # filter out non-temp movements - so if the last movement was
        # not temp, the resulting array will not have an entry for that offender
        movements.select { |m| m.out? && m.temporary? }.index_by(&:offender_no)
      end
    end
  end
end
