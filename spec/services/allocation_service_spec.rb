require 'rails_helper'

describe AllocationService do
  include ActiveJob::TestHelper

  let(:nomis_offender_id) { 'G4273GI' }

  before do
    # needed as create_or_update calls a NOMIS API
    signin_spo_user
  end

  describe '#allocate_secondary', :queueing do
    let(:moic_test_id) { 485_758 }
    let(:ross_id) { 485_926 }
    let(:primary_pom_id) { ross_id }
    let(:secondary_pom_id) { moic_test_id }
    let(:message) { 'Additional text' }

    let!(:allocation) {
      create(:allocation,
             nomis_offender_id: nomis_offender_id,
             primary_pom_nomis_id: primary_pom_id,
             primary_pom_name: 'Pom, Moic')
    }

    it 'sends an email to both primary and secondary POMS', vcr: { cassette_name: 'prison_api/allocation_service_allocate_secondary' } do
      expect {
        described_class.allocate_secondary(nomis_offender_id: nomis_offender_id,
                                           secondary_pom_nomis_id: secondary_pom_id,
                                           created_by_username: 'MOIC_POM',
                                           message: message
        )
        expect(allocation.reload.secondary_pom_nomis_id).to eq(secondary_pom_id)
        expect(allocation.reload.secondary_pom_name).to eq('INTEGRATION-TESTS, MOIC')
      }.to change(enqueued_jobs, :count).by(2)

      primary_email_job, secondary_email_job = enqueued_jobs.last(2)

      # mail telling the primary POM about the co-working POM
      primary_args_hash = primary_email_job[:args][3]['args'][0]
      secondary_args_hash = secondary_email_job[:args][3]['args'][0]
      expect(primary_args_hash).
        to match(
          hash_including(
            "message" => message,
            "offender_name" => "Abbella, Ozullirn",
            "nomis_offender_id" => nomis_offender_id,
            "pom_email" => "pom@digital.justice.gov.uk",
            "pom_name" => "Moic",
            "url" => "http://localhost:3000/prisons/LEI/staff/#{primary_pom_id}/caseload"
          ))

      # message telling co-working POM who the Primary POM is.
      expect(secondary_args_hash).
        to match(
          hash_including(
            "message" => message,
            "pom_name" => "Moic",
            "offender_name" => "Abbella, Ozullirn",
            "nomis_offender_id" => nomis_offender_id,
            "responsibility" => "supporting",
            "responsible_pom_name" => 'Pom, Moic',
            "pom_email" => "ommiicc@digital.justice.gov.uk",
            "url" => "http://localhost:3000/prisons/LEI/staff/#{secondary_pom_id}/caseload"
          ))
    end
  end

  describe '#create_or_update' do
    context 'without an existing' do
      before do
        create(:case_information, nomis_offender_id: nomis_offender_id)
        stub_auth_token
        stub_request(:get, "#{ApiHelper::T3}/users/MOIC_POM").
          to_return(body: { staffId: 1, firstName: "MOIC", lastName: 'POM' }.to_json)
        stub_pom_emails 1, []
        stub_offender(build(:nomis_offender, offenderNo: nomis_offender_id))
        stub_poms prison_code, [pom]
      end

      let(:prison_code) { build(:prison).code }
      let(:pom) { build(:pom, staffId: 485_833) }

      it 'can create a new record' do
        params = {
          nomis_offender_id: nomis_offender_id,
          prison: prison_code,
          allocated_at_tier: 'A',
          primary_pom_nomis_id: 485_833,
          primary_pom_allocated_at: DateTime.now.utc,
          nomis_booking_id: 1,
          recommended_pom_type: 'probation',
          event: Allocation::ALLOCATE_PRIMARY_POM,
          event_trigger: Allocation::USER,
          created_by_username: 'MOIC_POM'
        }

        expect {
          described_class.create_or_update(params)
        }.to change(Allocation, :count).by(1)
      end
    end

    context 'when one already exists' do
      before do
        create(:allocation, nomis_offender_id: nomis_offender_id)
      end

      it 'can update a record and store a version', vcr: { cassette_name: 'prison_api/allocation_service_update_allocation_spec' } do
        update_params = {
          nomis_offender_id: nomis_offender_id,
          allocated_at_tier: 'B',
          primary_pom_nomis_id: 485_926,
          event: Allocation::REALLOCATE_PRIMARY_POM,
          created_by_username: 'MOIC_POM'
        }

        expect {
          expect {
            described_class.create_or_update(update_params)
          }.not_to change(Allocation, :count)
        }.to change { Allocation.find_by(nomis_offender_id: nomis_offender_id).versions.count }.by(1)
      end
    end
  end

  describe '#allocations' do
    it "Can get allocations by prison", vcr: { cassette_name: 'prison_api/allocation_service_get_allocations_by_prison' } do
      first_offender_id = 'JSHD000NN'
      second_offender_id = 'SDHH87GD'
      leeds_prison = 'LEI'

      create(
        :allocation,
        nomis_offender_id: first_offender_id,
        prison: leeds_prison
      )

      create(
        :allocation,
        nomis_offender_id: second_offender_id,
        prison: 'USK'
      )

      allocations = described_class.active_allocations([first_offender_id, second_offender_id], leeds_prison)

      expect(allocations.keys.count).to be(1)
      expect(allocations.keys.first).to eq(first_offender_id)
    end
  end

  describe '#previously_allocated_poms' do
    it "Can get previous poms for an offender where there are none", vcr: { cassette_name: 'prison_api/allocation_service_previous_allocations_none' } do
      staff_ids = described_class.previously_allocated_poms('GDF7657')

      expect(staff_ids).to eq([])
    end

    it "Can get previous poms for an offender where there are some", vcr: { cassette_name: 'prison_api/allocation_service_previous_allocations' } do
      nomis_offender_id = 'GHF1234'
      previous_primary_pom_nomis_id = 345_567
      updated_primary_pom_nomis_id = 485_926

      allocation = create(
        :allocation,
        nomis_offender_id: nomis_offender_id,
        primary_pom_nomis_id: previous_primary_pom_nomis_id)

      allocation.update!(
        primary_pom_nomis_id: updated_primary_pom_nomis_id,
        event: Allocation::REALLOCATE_PRIMARY_POM
      )

      staff_ids = described_class.previously_allocated_poms(nomis_offender_id)

      expect(staff_ids.count).to eq(1)
      expect(staff_ids.first).to eq(previous_primary_pom_nomis_id)
    end
  end

  it 'can get the current allocated primary POM', vcr: { cassette_name: 'prison_api/current_allocated_primary_pom' }  do
    previous_primary_pom_nomis_id = 485_637
    updated_primary_pom_nomis_id = 485_926

    allocation = create(
      :allocation,
      nomis_offender_id: nomis_offender_id,
      primary_pom_nomis_id: previous_primary_pom_nomis_id)

    allocation.update!(
      primary_pom_nomis_id: updated_primary_pom_nomis_id,
      event: Allocation::REALLOCATE_PRIMARY_POM
    )

    current_pom = described_class.current_pom_for(nomis_offender_id, 'LEI')

    expect(current_pom.first_name).to eq("Moic")
    expect(current_pom.last_name).to eq("Pom")
    expect(current_pom.position_description).to eq("Prison Officer")
  end

  describe '#allocation_history_pom_emails' do
    it 'can retrieve all the POMs email addresses for ', vcr: { cassette_name: 'prison_api/allocation_service_history_spec' } do
      previous_primary_pom_nomis_id = 485_637
      updated_primary_pom_nomis_id = 485_926
      secondary_pom_nomis_id = 485_833

      allocation = create(
        :allocation,
        nomis_offender_id: nomis_offender_id,
        primary_pom_nomis_id: previous_primary_pom_nomis_id)

      allocation.update!(
        primary_pom_nomis_id: updated_primary_pom_nomis_id,
        event: Allocation::REALLOCATE_PRIMARY_POM
      )

      allocation.update!(
        secondary_pom_nomis_id: secondary_pom_nomis_id,
        event: Allocation::ALLOCATE_SECONDARY_POM
      )

      alloc = Allocation.find_by!(nomis_offender_id: nomis_offender_id)
      emails = described_class.allocation_history_pom_emails(alloc)

      expect(emails.count).to eq(3)
    end
  end
end
