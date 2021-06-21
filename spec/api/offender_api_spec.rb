# frozen_string_literal: true

require 'swagger_helper'

# The DescribeClass cop has been disabled as it is insists that the describe
# block contain the name of the tested class.  However rswag is using this
# text as part of the API documentation generated from these tests.
# rubocop:disable RSpec/DescribeClass
# rubocop:disable RSpec/EmptyExampleGroup
# Authorization 'method' needs to be defined for rswag
# rubocop:disable RSpec/VariableName
describe 'Offender Early Allocation API', vcr: { cassette_name: 'prison_api/offender_api' } do
  let!(:private_key) { OpenSSL::PKey::RSA.generate 2048 }
  let!(:public_key) { Base64.strict_encode64(private_key.public_key.to_s) }
  let!(:payload) {
    {
      user_name: 'test-user',
      scope: ['read'],
      exp: 4.hours.from_now.to_i
    }
  }
  let!(:token) { JWT.encode payload, private_key, 'RS256' }

  before {
    allow(Rails.configuration).to receive(:nomis_oauth_public_key).and_return(public_key)
  }

  path '/api/offenders/{offender_no}' do
    get 'Retrieves the early allocation status for an prisoner' do
      tags 'Early Allocations'
      produces 'application/json'
      parameter name: :offender_no, in: :path, type: :string

      response '200', 'Offender has an early allocation' do
        security [Bearer: []]
        schema type: :object,
               properties: {
                 offender_no: { type: :string },
                 early_allocation_eligibility_status: {
                   type: :boolean,
                   description: "true if prisoner is subject to early allocation, and so has an early handover date"
                 }
               },
               required: %w[offender_no early_allocation_eligibility_status]

        let(:offender_no) { 'G7266VD' }
        let!(:allocation) {
          create(:case_information, offender: build(:offender, nomis_offender_id: offender_no, early_allocations: build_list(:early_allocation, 1)))
        }
        let(:Authorization) { "Bearer #{token}" }

        run_test! do |_|
          expect(JSON.parse(response.body).fetch('offender_no')).to eq(offender_no)
          expect(JSON.parse(response.body).fetch('early_allocation_eligibility_status')).to eq(true)
        end
      end

      response '401', 'Request is not authorised' do
        security [Bearer: []]
        schema type: :object,
               properties: {
                 status: { type: :string },
                 message: { type: :string }
               }

        let(:offender_no) { 'A1111AA' }
        let(:Authorization) { "Bearer missing" }
        run_test!
      end

      response '404', 'offender not found' do
        security [Bearer: []]
        schema type: :object,
               properties: {
                 status: { type: :string },
                 message: { type: :string }
               }

        let(:offender_no) { 'A1111AA' }
        let(:Authorization) { "Bearer #{token}" }
        run_test!
      end
    end
  end
end
# rubocop:enable RSpec/VariableName
# rubocop:enable RSpec/EmptyExampleGroup
# rubocop:enable RSpec/DescribeClass
