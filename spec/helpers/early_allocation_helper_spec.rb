# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EarlyAllocationHelper, type: :helper do
  let(:early_allocations) { [] }
  let(:prison) { create(:prison) }
  let(:offender_sentence) { build(:sentence_detail) }
  let(:api_offender) { build(:hmpps_api_offender, sentence: offender_sentence) }
  let(:nomis_offender_id) { api_offender.offender_no }
  let!(:case_info) { create(:case_information, offender: build(:offender, nomis_offender_id: nomis_offender_id, early_allocations: early_allocations)) }
  let(:offender) { build(:mpc_offender, prison: prison, offender: case_info.offender, prison_record: api_offender) }

  describe '#early_allocation_status' do
    subject { helper.early_allocation_status_text(offender) }

    context 'with no saved assessment' do
      let(:early_allocations) { [] }

      it 'reads "Not assessed"' do
        expect(subject).to eq('Not assessed')
      end
    end

    context 'with saved assessments' do
      context 'when the offender has more than 18 months left to serve' do
        # The offender is not in the Early Allocation referral window
        let(:offender_sentence) { build(:sentence_detail, conditionalReleaseDate: Time.zone.today + 19.months) }
        let(:early_allocations) { build_list(:early_allocation, 1, created_within_referral_window: false) }

        it 'reads "Has saved assessments"' do
          expect(subject).to eq('Has saved assessments')
        end
      end

      context 'when the offender has less than 18 months left to serve (or exactly 18 months)' do
        # The offender is within the Early Allocation referral window
        let(:offender_sentence) { build(:sentence_detail, conditionalReleaseDate: Time.zone.today + 17.months) }

        context 'when the latest assessment was completed within the 18 month referral window' do
          context 'when the outcome was automatically "eligible"' do
            let(:early_allocations) {
              build_list(:early_allocation, 1, :eligible, created_within_referral_window: true)
            }

            it 'reads "Eligible - case handover date has been updated"' do
              expect(subject).to eq('Eligible - case handover date has been updated')
            end
          end

          context 'when the outcome was "discretionary" (so the community need to decide)' do
            context "when POM hasn't recorded the community decision yet" do
              let(:early_allocations) {
                build_list(:early_allocation, 1, :discretionary, created_within_referral_window: true)
              }

              it 'reads "Discretionary - the community probation team will make a decision"' do
                expect(subject).to eq('Discretionary - the community probation team will make a decision')
              end
            end

            context "when the community accepted the case" do
              let(:early_allocations) {
                build_list(:early_allocation, 1, :discretionary_accepted, created_within_referral_window: true)
              }

              it 'reads "Eligible - case handover date has been updated"' do
                expect(subject).to eq('Eligible - case handover date has been updated')
              end
            end

            context "when the community rejected the case" do
              let(:early_allocations) {
                build_list(:early_allocation, 1, :discretionary_declined, created_within_referral_window: true)
              }

              it 'reads "Has saved assessments"' do
                expect(subject).to eq('Has saved assessments')
              end
            end
          end

          context 'when the outcome was "not eligible"' do
            let(:early_allocations) {
              build_list(:early_allocation, 1, :ineligible, created_within_referral_window: true)
            }

            it 'reads "Has saved assessments"' do
              expect(subject).to eq('Has saved assessments')
            end
          end
        end

        context 'when assessments were completed outside of the referral window (but none inside)' do
          context 'when at least one assessment had an outcome of automatically "eligible"' do
            let(:early_allocations) {
              # 1 eligible + 5 ineligible
              build_list(:early_allocation, 1, :eligible, created_within_referral_window: false) +
              build_list(:early_allocation, 5, :ineligible, created_within_referral_window: false)
            }

            it 'reads "New assessment required"' do
              expect(subject).to eq('New assessment required')
            end
          end

          context 'when at least one assessment had an outcome of "discretionary"' do
            let(:early_allocations) {
              # 1 discretionary + 5 ineligible
              build_list(:early_allocation, 1, :discretionary, created_within_referral_window: false) +
              build_list(:early_allocation, 5, :ineligible, created_within_referral_window: false)
            }

            it 'reads "New assessment required"' do
              expect(subject).to eq('New assessment required')
            end
          end

          context 'when all assessment outcomes are "not eligible"' do
            let(:early_allocations) {
              build_list(:early_allocation, 5, :ineligible, created_within_referral_window: false)
            }

            it 'reads "Has saved assessments"' do
              expect(subject).to eq('Has saved assessments')
            end
          end
        end
      end
    end
  end

  describe '#early_allocation_action_link' do
    shared_examples 'Check and reassess' do
      it 'reads "Check and reassess"' do
        expect(text).to eq('Check and reassess')
      end

      it 'links to the Early Allocation start page for the offender' do
        expect(href).to eq(start_page_path)
      end
    end

    subject { helper.early_allocation_action_link(offender, prison) }

    let(:link) { Nokogiri::HTML(subject).css('a') }
    let(:text) { link.text }
    let(:href) { link.attr('href').to_s }

    let(:start_page_path) { prison_prisoner_early_allocations_path(prison.code, nomis_offender_id) }

    context 'with no saved assessment' do
      let(:early_allocations) { [] }

      it 'reads "Start assessment"' do
        expect(text).to eq('Start assessment')
      end

      it 'links to the Early Allocation start page for the offender' do
        expect(href).to eq(start_page_path)
      end
    end

    context 'with saved assessments' do
      context 'when the offender has more than 18 months left to serve' do
        # The offender is not in the Early Allocation referral window
        let(:offender_sentence) { build(:sentence_detail, conditionalReleaseDate: Time.zone.today + 19.months) }
        let(:early_allocations) { build_list(:early_allocation, 1, created_within_referral_window: false) }

        include_examples 'Check and reassess'
      end

      context 'when the offender has less than 18 months left to serve (or exactly 18 months)' do
        # The offender is within the Early Allocation referral window
        let(:offender_sentence) { build(:sentence_detail, conditionalReleaseDate: Time.zone.today + 17.months) }

        context 'when the latest assessment was completed within the 18 month referral window' do
          context 'when the outcome was automatically "eligible"' do
            let(:early_allocations) {
              build_list(:early_allocation, 1, :eligible, created_within_referral_window: true)
            }

            it 'reads "View assessment"' do
              expect(text).to eq('View assessment')
            end

            it 'links to the page to view details of the assessment' do
              view_assessment_path = prison_prisoner_early_allocation_path(prison.code, nomis_offender_id, early_allocations.first.id)
              expect(href).to eq(view_assessment_path)
            end
          end

          context 'when the outcome was "discretionary" (so the community need to decide)' do
            context "when POM hasn't recorded the community decision yet" do
              let(:early_allocations) {
                build_list(:early_allocation, 1, :discretionary, created_within_referral_window: true)
              }

              it 'reads "Record community decision"' do
                expect(text).to eq('Record community decision')
              end

              it 'links to the page to record the community decision' do
                record_decision_path = edit_prison_prisoner_latest_early_allocation_path(prison.code, nomis_offender_id)
                expect(href).to eq(record_decision_path)
              end
            end

            context "when the community accepted the case" do
              let(:early_allocations) {
                build_list(:early_allocation, 1, :discretionary_accepted, created_within_referral_window: true)
              }

              it 'reads "View assessment"' do
                expect(text).to eq('View assessment')
              end

              it 'links to the page to view details of the assessment' do
                view_assessment_path = prison_prisoner_early_allocation_path(prison.code, nomis_offender_id, early_allocations.first.id)
                expect(href).to eq(view_assessment_path)
              end
            end

            context "when the community rejected the case" do
              let(:early_allocations) {
                build_list(:early_allocation, 1, :discretionary_declined, created_within_referral_window: true)
              }

              include_examples 'Check and reassess'
            end
          end

          context 'when the outcome was "not eligible"' do
            let(:early_allocations) {
              build_list(:early_allocation, 1, :ineligible, created_within_referral_window: true)
            }

            include_examples 'Check and reassess'
          end
        end

        context 'when the latest assessment was completed outside of the referral window' do
          let(:early_allocations) {
            build_list(:early_allocation, 1, created_within_referral_window: false)
          }

          include_examples 'Check and reassess'
        end
      end
    end
  end

  describe '#early_allocation_outcome' do
    subject { helper.early_allocation_outcome(early_allocation) }

    let(:early_allocation) { build(:early_allocation) }

    context 'when eligible' do
      let(:early_allocation) { build(:early_allocation) }

      it 'says "Eligible"' do
        expect(subject).to eq('Eligible')
      end
    end

    context 'when ineligible' do
      let(:early_allocation) { build(:early_allocation, :ineligible) }

      it 'says "Not eligible"' do
        expect(subject).to eq('Not eligible')
      end
    end

    context 'when deferred' do
      let(:early_allocation) { build(:early_allocation, :discretionary) }

      it 'says "Waiting for community decision"' do
        expect(subject).to eq('Waiting for community decision')
      end
    end

    context 'when discretionary and community said accepted' do
      let(:early_allocation) { build(:early_allocation, :discretionary_accepted) }

      it 'says "Eligible"' do
        expect(subject).to eq('Eligible')
      end
    end

    context 'when discretionary and community has rejected' do
      let(:early_allocation) { build(:early_allocation, :discretionary_declined) }

      it 'says "Not eligible"' do
        expect(subject).to eq('Not eligible')
      end
    end
  end

  describe '#early_allocation_long_outcome' do
    context 'when eligible and unsent' do
      let(:early_allocation) { build(:early_allocation, :eligible, :pre_window) }

      it 'works' do
        expect(helper.early_allocation_long_outcome(early_allocation)).to eq('Eligible - assessment not sent to the community probation team')
      end
    end

    context 'when eligible and sent' do
      let(:early_allocation) { build(:early_allocation, :eligible) }

      it 'works' do
        expect(helper.early_allocation_long_outcome(early_allocation)).to eq('Eligible - the community probation team will take responsibility for this case early')
      end
    end

    context 'when not eligible' do
      let(:early_allocation) { build(:early_allocation, :ineligible) }

      it 'works' do
        expect(helper.early_allocation_long_outcome(early_allocation)).to eq('Not eligible')
      end
    end

    context 'when discretionary - not sent' do
      let(:early_allocation) { build(:early_allocation, :discretionary, :pre_window) }

      it 'works' do
        expect(helper.early_allocation_long_outcome(early_allocation)).to eq('Discretionary - assessment not sent to the community probation team')
      end
    end

    context 'when discretionary - sent' do
      let(:early_allocation) { build(:early_allocation, :discretionary) }

      it 'works' do
        expect(helper.early_allocation_long_outcome(early_allocation)).to eq('Discretionary - the community probation team will make a decision')
      end
    end

    context 'when discretionary - accepted' do
      let(:early_allocation) { build(:early_allocation, :discretionary, community_decision: true) }

      it 'works' do
        expect(helper.early_allocation_long_outcome(early_allocation)).to eq('Eligible - the community probation team will take responsibility for this case early')
      end
    end

    context 'when discretionary - rejected' do
      let(:early_allocation) { build(:early_allocation, :discretionary, community_decision: false) }

      it 'works' do
        expect(helper.early_allocation_long_outcome(early_allocation)).to eq('Not eligible')
      end
    end
  end
end
