require 'rails_helper'

RSpec.describe OffenderHelper do
  describe 'Digital Prison Services profile path' do
    it "formats the link to an offender's profile page within the Digital Prison Services" do
      expect(digital_prison_service_profile_path('AB1234A')).to eq("#{Rails.configuration.digital_prison_service_host}/offenders/AB1234A/quick-look")
    end
  end

  describe '#event_type' do
    let(:nomis_staff_id) { 456_789 }
    let(:nomis_offender_id) { 123_456 }

    let!(:allocation) {
      create(
        :allocation,
        nomis_offender_id: nomis_offender_id,
        primary_pom_nomis_id: nomis_staff_id,
        event: 'allocate_primary_pom'
      )
    }

    it 'returns the event in a more readable format' do
      expect(helper.last_event(allocation)).to eq("POM allocated - #{allocation.updated_at.strftime('%d/%m/%Y')}")
    end
  end

  describe '#pom_responsibility_label' do
    context 'when responsible' do
      let(:offender) { build(:offender) }

      it 'shows responsible' do
        expect(helper.pom_responsibility_label(offender)).to eq('Responsible')
      end
    end

    context 'when supporting' do
      let(:offender) { build(:offender, :determinate_recall) }

      it 'shows supporting' do
        expect(helper.pom_responsibility_label(offender)).to eq('Supporting')
      end
    end

    context 'when unknown' do
      let(:offender) { build(:offender, sentence: build(:sentence_detail, :unsentenced, conditionalReleaseDate: nil)) }

      it 'shows unknown' do
        expect(helper.pom_responsibility_label(offender)).to eq('Unknown')
      end
    end
  end

  describe 'generates labels for case owner ' do
    it 'can show Custody for Prison' do
      off = build(:offender).tap { |o|
        o.load_case_information(build(:case_information))
        o.sentence = HmppsApi::SentenceDetail.from_json('sentenceStartDate' => (Time.zone.today - 20.months).to_s,
                                                         'automaticReleaseDate' => (Time.zone.today + 20.months).to_s)
      }
      offp = OffenderPresenter.new(off)

      expect(helper.case_owner_label(offp)).to eq('Custody')
    end

    it 'can show Community for Probation' do
      off = build(:offender).tap { |o|
        o.sentence = HmppsApi::SentenceDetail.from_json("automaticReleaseDate" => Time.zone.today.to_s)
      }
      offp = OffenderPresenter.new(off)

      expect(helper.case_owner_label(offp)).to eq('Community')
    end

    context 'when unknown' do
      let(:offender) { build(:offender, sentence: build(:sentence_detail, :unsentenced, conditionalReleaseDate: nil)) }

      it 'can show Unknown' do
        expect(helper.case_owner_label(offender)).to eq('Unknown')
      end
    end
  end

  describe '#approaching_handover_without_com?' do
    it 'returns false if offender is not sentenced' do
      offender = build(:offender).tap { |o|
        o.load_case_information(build(:case_information))
        o.sentence = HmppsApi::SentenceDetail.from_json('sentenceStartDate' => (Time.zone.today - 20.months).to_s,
                                                         'automaticReleaseDate' => (Time.zone.today + 20.months).to_s)
      }

      expect(offender.sentenced?).to eq(false)
      expect(helper.needs_com_but_ldu_is_uncontactable?(offender)).to eq(false)
    end

    it 'returns false if offender does not have a handover start date' do
      offender = build(:offender, :indeterminate).tap { |o|
        o.load_case_information(build(:case_information))
        o.sentence = HmppsApi::SentenceDetail.from_json('sentenceStartDate' => (Time.zone.today + 20.months).to_s,
            )
      }

      expect(helper.needs_com_but_ldu_is_uncontactable?(offender)).to eq(false)
    end

    it 'returns false if offender has more than 45 days until start of handover' do
      offender = build(:offender).tap { |o|
        o.load_case_information(build(:case_information))
        o.sentence = HmppsApi::SentenceDetail.from_json('sentenceStartDate' => (Time.zone.today - 20.months).to_s,
                                                         'automaticReleaseDate' => (Time.zone.today + 20.months).to_s,
                                                         'releaseDate' => (Time.zone.today + 20.months).to_s)
      }

      expect(helper.needs_com_but_ldu_is_uncontactable?(offender)).to eq(false)
    end

    context 'when offender has 45 days or less until start of handover' do
      it "returns false if offender has a 'COM'" do
        offender = build(:offender).tap { |o|
          o.load_case_information(build(:case_information, com_name: "Betty White"))
          o.sentence = HmppsApi::SentenceDetail.from_json('sentenceStartDate' => (Time.zone.today - 20.months).to_s,
                                                           'automaticReleaseDate' => (Time.zone.today + 8.months).to_s,
                                                           'releaseDate' => (Time.zone.today + 20.months).to_s)
        }

        expect(helper.needs_com_but_ldu_is_uncontactable?(offender)).to eq(false)
      end

      context "when offender has no 'COM'" do
        it "returns false if offender has an LDU email address" do
          offender = build(:offender).tap { |o|
            o.load_case_information(build(:case_information))
            o.sentence = HmppsApi::SentenceDetail.from_json('sentenceStartDate' => (Time.zone.today - 20.months).to_s,
                                                             'automaticReleaseDate' => (Time.zone.today + 8.months).to_s,
                                                             'releaseDate' => (Time.zone.today + 20.months).to_s)
          }

          expect(helper.needs_com_but_ldu_is_uncontactable?(offender)).to eq(false)
        end

        it "returns true if offender has no LDU" do
          offender = build(:offender).tap { |o|
            o.load_case_information(build(:case_information, team: nil))
            o.sentence = HmppsApi::SentenceDetail.from_json('sentenceStartDate' => (Time.zone.today - 20.months).to_s,
                                                              'automaticReleaseDate' => (Time.zone.today + 8.months).to_s,
                                                              'releaseDate' => (Time.zone.today + 20.months).to_s)
          }

          expect(helper.needs_com_but_ldu_is_uncontactable?(offender)).to eq(true)
        end

        it "returns true if offender has an LDU without an email address" do
          offender = build(:offender).tap { |o|
            o.load_case_information(build(:case_information,
                                          team: build(:team, local_divisional_unit: build(:local_divisional_unit, email_address: nil))))
            o.sentence = HmppsApi::SentenceDetail.from_json('sentenceStartDate' => (Time.zone.today - 20.months).to_s,
                                                              'automaticReleaseDate' => (Time.zone.today + 8.months).to_s,
                                                              'releaseDate' => (Time.zone.today + 20.months).to_s)
          }

          expect(helper.needs_com_but_ldu_is_uncontactable?(offender)).to eq(true)
        end
      end
    end
  end
end
