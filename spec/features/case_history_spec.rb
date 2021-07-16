# frozen_string_literal: true

require 'rails_helper'

feature 'Case History' do
  let(:probation_pom) do
    {
      primary_pom_nomis_id: 485_926,
      primary_pom_name: 'Pom, Moic',
      email: 'pom@digital.justice.gov.uk'
    }
  end

  let(:prison_pom) do
    {
      primary_pom_nomis_id: 485_833,
      primary_pom_name: 'Ricketts, Andrien',
      email: 'andrien.ricketts@digital.justice.gov.uk'
    }
  end

  let(:probation_pom_2) do
    {
      primary_pom_nomis_id: 485_637,
      primary_pom_name: 'Pobee-Norris, Kath',
      email: 'kath.pobee-norris@digital.justice.gov.uk'
    }
  end

  let(:pom_without_email) do
    {
      primary_pom_nomis_id: 485_636,
      primary_pom_name: "#{Faker::Name.last_name}, #{Faker::Name.first_name}"
    }
  end

  let(:spo) { build(:pom) }

  let(:nomis_offender) {
    build(:nomis_offender,
          agencyId: open_prison.code,
            sentence: attributes_for(:sentence_detail, :indeterminate, :welsh_open_policy))
  }
  let(:nomis_pentonville_offender) {
    build(:nomis_offender, offenderNo: nomis_offender.fetch(:offenderNo),
          agencyId: second_prison.code,
            sentence: attributes_for(:sentence_detail, :indeterminate, :welsh_open_policy))
  }
  let(:pontypool_ldu) {
    create(:local_delivery_unit, name: 'Pontypool LDU', email_address: 'pontypool-ldu@digital.justice.gov.uk')
  }
  let(:ci) { create(:case_information, offender: build(:offender, nomis_offender_id: nomis_offender.fetch(:offenderNo)), local_delivery_unit: pontypool_ldu) }
  let(:nomis_offender_id) { ci.nomis_offender_id }
  let!(:first_prison) { create(:prison) }
  let!(:second_prison) { create(:prison) }
  let!(:open_prison) { create(:prison, code: PrisonService::PRESCOED_CODE) }
  let(:offender_movements) {
    [
    attributes_for(:movement, toAgency: first_prison.code, movementDate: first_arrival_date - 1.day),
    attributes_for(:movement, toAgency: second_prison.code, movementDate: readmission_date),
    attributes_for(:movement, toAgency: open_prison.code, movementDate: transfer_date),
  ]
  }
  let(:today) { Time.zone.now } # try not to call Time.zone.now too often, to avoid 1-minute drifts
  let(:first_arrival_date) { today - 20.days }
  let(:deallocate_date) { today - 14.days }
  let(:readmission_date) { today - 10.days }
  let(:transfer_date) { today - 5.days }

  before do
    Timecop.travel DateTime.new 2021, 2, 28, 11, 25, 35
    stub_auth_token
  end

  after do
    Timecop.return
  end

  describe 'offender allocation history' do
    before {
      stub_offenders_for_prison(open_prison.code, [nomis_offender], offender_movements)
      stub_signin_spo spo, [open_prison.code]

      stub_pom build(:pom, staffId: probation_pom_2.fetch(:primary_pom_nomis_id))
      stub_pom_emails(probation_pom_2.fetch(:primary_pom_nomis_id), [probation_pom_2.fetch(:email)])

      stub_pom build(:pom, staffId: pom_without_email.fetch(:primary_pom_nomis_id))
      stub_pom_emails(pom_without_email.fetch(:primary_pom_nomis_id), [])

      stub_pom build(:pom, staffId: probation_pom.fetch(:primary_pom_nomis_id))
      stub_pom_emails(probation_pom.fetch(:primary_pom_nomis_id), [probation_pom.fetch(:email)])

      stub_pom build(:pom, staffId: prison_pom.fetch(:primary_pom_nomis_id))
      stub_pom_emails(prison_pom.fetch(:primary_pom_nomis_id), [prison_pom.fetch(:email)])
    }

    context 'when on the allocation history page' do
      before do
        # create a plausible timeline involving 3 prisons over a period of several days
        current_date = first_arrival_date
        allocation = Timecop.travel current_date do
          create(
            :allocation_history,
            prison: first_prison.code,
            event: AllocationHistory::ALLOCATE_PRIMARY_POM,
            event_trigger: AllocationHistory::USER,
            nomis_offender_id: nomis_offender_id,
            primary_pom_nomis_id: probation_pom[:primary_pom_nomis_id],
            primary_pom_name: probation_pom[:primary_pom_name],
            recommended_pom_type: 'prison',
            override_reasons: ["suitability"],
            suitability_detail: "Too high risk",
            primary_pom_allocated_at: current_date
          )
        end
        current_date += 1.day
        Timecop.travel current_date do
          allocation.update!(event: AllocationHistory::REALLOCATE_PRIMARY_POM,
                             event_trigger: AllocationHistory::USER,
                             primary_pom_nomis_id: probation_pom_2[:primary_pom_nomis_id],
                             primary_pom_name: probation_pom_2[:primary_pom_name],
                             recommended_pom_type: 'probation')
        end
        current_date += 1.day
        Timecop.travel current_date do
          allocation.update!(event: AllocationHistory::ALLOCATE_SECONDARY_POM,
                             secondary_pom_nomis_id: probation_pom[:primary_pom_nomis_id],
                             secondary_pom_name: probation_pom[:primary_pom_name])
        end
        current_date += 1.day
        Timecop.travel current_date do
          allocation.update!(event: AllocationHistory::DEALLOCATE_SECONDARY_POM,
                             secondary_pom_nomis_id: nil,
                             secondary_pom_name: nil)
        end
        # release offender (properly)
        Timecop.travel(deallocate_date) do
          MovementService.process_movement build(:movement, :release, offenderNo: allocation.nomis_offender_id)
        end
        # Now the offender is admitted to Pentonville having been released from Leeds earlier
        current_date = readmission_date
        Timecop.travel(current_date) do
          # offender got released - so have to re-create case information record
          # and re-find allocation record as it has been updated
          create(:case_information, nomis_offender_id: nomis_offender_id, local_delivery_unit: pontypool_ldu)
          allocation = AllocationHistory.find_by!(nomis_offender_id: nomis_offender_id)
          allocation.update!(event: AllocationHistory::ALLOCATE_PRIMARY_POM,
                             event_trigger: AllocationHistory::USER,
                             prison: second_prison.code,
                             primary_pom_nomis_id: prison_pom[:primary_pom_nomis_id],
                             primary_pom_name: prison_pom[:primary_pom_name],
                             recommended_pom_type: 'prison')
        end

        current_date += 1.day
        Timecop.travel(current_date) do
          create(:early_allocation, offender: ci.offender, prison: second_prison.code, nomis_offender_id: nomis_offender_id)
          create :email_history, nomis_offender_id: nomis_offender_id,
                 name: ci.local_delivery_unit.name,
                 email: ci.local_delivery_unit.email_address,
                 event: EmailHistory::AUTO_EARLY_ALLOCATION,
                 prison: second_prison.code
        end

        current_date += 1.day
        Timecop.travel(current_date) do
          create(:early_allocation, :discretionary,
                 offender: ci.offender, prison: second_prison.code, nomis_offender_id: nomis_offender_id)
          create :email_history, nomis_offender_id: nomis_offender_id,
                 name: ci.local_delivery_unit.name,
                 email: ci.local_delivery_unit.email_address,
                 event: EmailHistory::DISCRETIONARY_EARLY_ALLOCATION,
                 prison: second_prison.code
        end

        current_date += 1.day
        Timecop.travel(current_date) do
          allocation.update!(event: AllocationHistory::REALLOCATE_PRIMARY_POM,
                             primary_pom_nomis_id: pom_without_email[:primary_pom_nomis_id],
                             primary_pom_name: pom_without_email[:primary_pom_name],
                             recommended_pom_type: 'probation')
          # Puy the offender in Pentonville to calculate handover dates
          # then put them back so that the transfer looks like it works
          stub_offender(nomis_pentonville_offender)
          RecalculateHandoverDateJob.perform_now nomis_offender_id
          stub_offender(nomis_offender)
          stub_movements_for(nomis_offender_id, offender_movements)
        end

        Timecop.travel(transfer_date) do
          # create Email History for welsh offender transferring to Prescoed open prison by moving the prisoner
          MovementService.process_transfer build(:movement, :transfer, offenderNo: nomis_offender_id, toAgency: open_prison.code)
          RecalculateHandoverDateJob.perform_now nomis_offender_id
        end
        visit history_prison_prisoner_allocation_path(open_prison.code, nomis_offender_id)
      end

      let(:formatted_deallocate_date) { deallocate_date.strftime("#{deallocate_date.day.ordinalize} %B %Y (%R)") }
      let(:formatted_transfer_date) { transfer_date.strftime("#{transfer_date.day.ordinalize} %B %Y") + " (" + transfer_date.strftime("%R") + ")" }
      let(:allocation) { AllocationHistory.last }
      let(:history) { allocation.get_old_versions.append(allocation).sort_by!(&:updated_at).reverse! }
      let(:created_by_name) { allocation.get_old_versions.first.created_by_name }
      let(:last_history) { allocation.get_old_versions.first }

      it 'has the correct headings' do
        expect(page).to have_css('h1', text: "#{nomis_offender.fetch(:lastName)}, #{nomis_offender.fetch(:firstName)}")
      end

      it 'has 3 prison sections' do
        #  expect 3 'prison' sections - Prescoed, Pentonville and Leeds
        expect(all('.govuk-grid-row').size).to eq(3)
      end

      it 'has a section for Prescoed transfer to open conditions' do
        # 1st Prison - Prescoed. This only contains the transfer to open conditions
        within '.govuk-grid-row:nth-of-type(1)' do
          expect(page).to have_css('.govuk-heading-m', text: "HMP/YOI Prescoed")

          expect(all('.moj-timeline__item').size).to eq(2)
          prescoed_transfer = EmailHistory.where(nomis_offender_id: nomis_offender_id, event: EmailHistory::OPEN_PRISON_COMMUNITY_ALLOCATION).first

          within '.moj-timeline__item:nth-of-type(1)' do
            [
              ['.moj-timeline__title', "Offender transferred to an open prison"],
              ['.moj-timeline__date', "#{prescoed_transfer.created_at.strftime("#{prescoed_transfer.created_at.day.ordinalize} %B %Y")} (#{prescoed_transfer.created_at.strftime('%R')}) email sent automatically"],
              ['.moj-timeline__description', "The LDU for #{prescoed_transfer.name} - #{prescoed_transfer.email} - was sent an email asking them to appoint a Supporting COM."]
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end
        end
      end

      it 'has the transfer at the bottom of Presceod list' do
        within '.govuk-grid-row:nth-of-type(1)' do
          within '.moj-timeline__item:nth-of-type(2)' do
            [
              ['.moj-timeline__title', "Prisoner unallocated"],
              ['.moj-timeline__date', formatted_transfer_date.to_s],
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end
        end
      end

      it 'has a Pentonville section with 6 items' do
        within '.govuk-grid-row:nth-of-type(2)' do
          expect(page).to have_css('.govuk-heading-m', text: second_prison.name)
          expect(all('.moj-timeline__item').size).to eq(6)
        end
      end

      it 'has a Pentonville section', :js do
        # 2nd Prison - Pentonville. This contains 6 events
        history1 = history[1]
        history2 = history[2]

        within '.govuk-grid-row:nth-of-type(2)' do
          within '.moj-timeline__item:nth-of-type(1)' do
            [
              ['.moj-timeline__title', "Prisoner reallocated"],
              ['.moj-timeline__description', [
                "Prisoner reallocated to #{history1.primary_pom_name.titleize} - (email address not found)",
                "Tier: #{history1.allocated_at_tier}",
                "Prison POM allocated instead of recommended Probation POM",
                "Reason(s):",
                "- Prisoner assessed as suitable for a probation POM despite tiering calculation",
                "Too high risk"
              ].join("\n")
              ],
              ['.moj-timeline__date', formatted_date_for(history1).to_s],
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end

          within '.moj-timeline__item:nth-of-type(2)' do
            [
              ['.moj-timeline__header', "Early allocation decision requested"],
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end

          within '.moj-timeline__item:nth-of-type(3)' do
            [
              ['.moj-timeline__header', "Early allocation assessment form completed"],
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end

          within '.moj-timeline__item:nth-of-type(4)' do
            [
              ['.moj-timeline__header', "Early allocation assessment form sent"],
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end

          within '.moj-timeline__item:nth-of-type(5)' do
            [
              ['.moj-timeline__header', "Early allocation assessment form completed"],
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end

          within '.moj-timeline__item:nth-of-type(6)' do
            [
              ['.moj-timeline__title', "Prisoner allocated"],
              ['.moj-timeline__description', ["Prisoner allocated to #{history2.primary_pom_name.titleize} - #{prison_pom[:email]}\n",
                                              "Tier: #{history2.allocated_at_tier}"].join],
              ['.moj-timeline__date', formatted_date_for(history2).to_s],
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end
        end
      end

      it 'shows the case history', :js do
        hist_allocate_secondary = AllocationHistory.new secondary_pom_name: probation_pom[:primary_pom_name],
                                                 updated_at: first_arrival_date + 2.days,
                                                 created_by_name: created_by_name

        history6 = AllocationHistory.new primary_pom_name: probation_pom_2[:primary_pom_name],
                                  updated_at: first_arrival_date + 1.day,
                                  created_by_name: created_by_name,
                                  allocated_at_tier: 'A'

        within '.govuk-grid-row:nth-of-type(3)' do
          expect(page).to have_css('.govuk-heading-m', text: first_prison.name)
          expect(all('.moj-timeline__item').size).to eq(5)

          within '.moj-timeline__item:nth-of-type(1)' do
            [
              ['.moj-timeline__title', "Prisoner unallocated"],
              ['.moj-timeline__date', "#{formatted_deallocate_date} by System Admin"],
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end

          within '.moj-timeline__item:nth-of-type(2)' do
            [
              ['.moj-timeline__title', "Co-working unallocated"],
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end

          within '.moj-timeline__item:nth-of-type(3)' do
            [
              ['.moj-timeline__title', "Co-working allocation"],
              ['.moj-timeline__description', "Prisoner allocated to #{hist_allocate_secondary.secondary_pom_name.titleize} - #{probation_pom[:email]}"],
              ['.moj-timeline__date', "#{formatted_date_for(hist_allocate_secondary)} by #{hist_allocate_secondary.created_by_name.titleize}"],
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end

          within '.moj-timeline__item:nth-of-type(4)' do
            [
              ['.moj-timeline__title', "Prisoner reallocated"],
              ['.moj-timeline__description', [
                "Prisoner reallocated to #{history6.primary_pom_name.titleize} - #{probation_pom_2[:email]}\n",
                "Tier: #{history6.allocated_at_tier}\n",
                "Prison POM allocated instead of recommended Probation POM\n",
                "Reason(s):\n",
                "- Prisoner assessed as suitable for a probation POM despite tiering calculation\n",
                "Too high risk"
              ].join],
              ['.moj-timeline__date', "#{formatted_date_for(history6)} by #{history6.created_by_name.titleize}"],
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end

          within '.moj-timeline__item:nth-of-type(5)' do
            [
              ['.moj-timeline__description', [
                "Prisoner allocated to #{last_history.primary_pom_name.titleize} - #{probation_pom[:email]}\n",
                "Tier: #{last_history.allocated_at_tier}"
              ].join],
              ['.moj-timeline__date', "#{formatted_date_for(last_history)} by #{last_history.created_by_name.titleize}"],
            ].each do |key, val|
              expect(page).to have_css(key, text: val)
            end
          end
        end
      end

      it 'links to previous Early Allocation assessments' do
        # The 5th history item is an 'eligible' early allocation assessment
        eligible_assessment = within '.govuk-grid-row:nth-of-type(2)' do
          page.find('.moj-timeline > .moj-timeline__item:nth-child(5)')
        end

        within eligible_assessment do
          expect(page).to have_css('.moj-timeline__title', text: 'Early allocation assessment form completed')
          expect(page).to have_link('View saved assessment')
          click_link 'View saved assessment'
        end

        # Assert that we're on the correct 'view' page
        target_early_allocation = EarlyAllocation.where(nomis_offender_id: nomis_offender_id).find(&:eligible?)
        view_assessment_page = prison_prisoner_early_allocation_path(open_prison.code, nomis_offender_id, target_early_allocation.id)
        expect(page).to have_current_path(view_assessment_page)
        expect(page).to have_content('Eligible')

        # Back link takes us back
        click_link 'Back'
        case_history_page = history_prison_prisoner_allocation_path(open_prison.code, nomis_offender_id)
        expect(page).to have_current_path(case_history_page)
      end
    end
  end

  def formatted_date_for(history)
    history.updated_at.strftime("#{history.updated_at.day.ordinalize} %B %Y") + " (" + history.updated_at.strftime("%R") + ")"
  end

  context 'with a simple case' do
    before do
      stub_user(username: 'MOIC_POM', staff_id: pom.staff_id)
      stub_offenders_for_prison(open_prison.code, [nomis_offender])
      stub_movements_for nomis_offender.fetch(:offenderNo), offender_movements
      signin_spo_user([open_prison.code])
      stub_poms(open_prison.code, [pom])
      stub_pom pom
    end

    let(:nomis_offender) { build(:nomis_offender, agencyId: open_prison.code) }
    let(:nomis_offender_id) { nomis_offender.fetch(:offenderNo) }
    let(:pom) { build(:pom) }
    let!(:case_info) {
      create(:case_information, offender: build(:offender, nomis_offender_id: nomis_offender_id))
    }
    let!(:allocation) {
      create(:allocation_history, :primary, nomis_offender_id: nomis_offender_id, prison: first_prison.code,
             primary_pom_nomis_id: pom.staff_id)
    }

    context 'with a discretionary accepted early allocation' do
      before do
        create(:early_allocation, :discretionary_accepted,
               updated_by_firstname: 'Fred', updated_by_lastname: 'Bloggs',
               offender: case_info.offender, prison: second_prison.code, nomis_offender_id: nomis_offender_id)
      end

      it 'displays 3 sections - allocation plus 2 early allocation records' do
        visit history_prison_prisoner_allocation_path(open_prison.code, nomis_offender_id)
        expect(all('.moj-timeline__item').size).to eq(3)
      end
    end

    context 'when VLO happens between allocation and de-allocation' do
      let(:tomorrow) { Time.zone.tomorrow }
      let(:day_after) { tomorrow + 1.day }

      before do
        Timecop.travel tomorrow do
          create(:victim_liaison_officer, offender: case_info.offender)
        end
        Timecop.travel day_after
        AllocationHistory.deallocate_primary_pom pom.staff_id, open_prison.code
      end

      after do
        Timecop.return
      end

      it 'displays all the data and doesnt crash' do
        visit history_prison_prisoner_allocation_path(open_prison.code, nomis_offender_id)
      end
    end
  end
end
