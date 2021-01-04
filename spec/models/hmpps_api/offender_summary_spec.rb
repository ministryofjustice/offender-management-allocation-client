require 'rails_helper'

describe HmppsApi::OffenderSummary do
  describe '#earliest_release_date' do
    context 'with blank sentence detail' do
      before { subject.sentence = HmppsApi::SentenceDetail.new }

      it 'responds with no earliest release date' do
        expect(subject.earliest_release_date).to be_nil
      end
    end

    context 'when main dates are missing' do
      let(:today_plus1) { Time.zone.today + 1.day }

      context 'with just the sentence expiry date' do
        before do
          subject.sentence = HmppsApi::SentenceDetail.new.tap { |s| s.sentence_expiry_date = today_plus1 }
        end

        it 'uses the SED' do
          expect(subject.earliest_release_date).to eq(today_plus1)
        end
      end

      context 'with many dates' do
        before do
          subject.sentence = HmppsApi::SentenceDetail.from_json(
            'licenceExpiryDate' => licence_expiry_date.to_s,
            'postRecallReleaseDate' => post_recall_release_date.to_s,
            'actualParoleDate' => actual_parole_date.to_s).tap { |detail|
            detail.sentence_expiry_date = sentence_expiry_date
          }
        end

        context 'with future dates' do
          let(:licence_expiry_date) { Time.zone.today + 2.days }
          let(:sentence_expiry_date) { Time.zone.today + 3.days }
          let(:post_recall_release_date) { Time.zone.today + 4.days }
          let(:actual_parole_date) { Time.zone.today + 5.days }

          context 'with licence date nearest' do
            let(:licence_expiry_date) { today_plus1 }

            it 'uses the licence expiry date' do
              expect(subject.earliest_release_date).to eq(licence_expiry_date)
            end
          end

          context 'with post_recall_release_date nearest' do
            let(:post_recall_release_date) { today_plus1 }

            it 'uses the post_recall_release_date' do
              expect(subject.earliest_release_date).to eq(post_recall_release_date)
            end
          end

          context 'with actual_parole_date nearest' do
            let(:actual_parole_date) { today_plus1 }

            it 'uses the actual_parole_date' do
              expect(subject.earliest_release_date).to eq(actual_parole_date)
            end
          end
        end

        context 'with all dates in the past' do
          let(:sentence_expiry_date) { Time.zone.today - 2.days }
          let(:licence_expiry_date) { Time.zone.today - 3.days }
          let(:post_recall_release_date) { Time.zone.today - 4.days }
          let(:actual_parole_date) { Time.zone.today - 5.days }

          it 'uses the closest to today' do
            expect(subject.earliest_release_date).to eq(sentence_expiry_date)
          end
        end
      end
    end

    context 'with sentence detail with dates' do
      before do
        subject.sentence = HmppsApi::SentenceDetail.from_json(
          'sentenceStartDate' => Date.new(2005, 2, 3).to_s,
          'paroleEligibilityDate' => parole_eligibility_date.to_s,
          'conditionalReleaseDate' => conditional_release_date.to_s)
      end

      context 'when comprised of dates in the past and the future' do
        let(:parole_eligibility_date) { Date.new(2009, 1, 1) }
        let(:automatic_release_date) { Time.zone.today }
        let(:conditional_release_date) { Time.zone.today + 3.days }

        it 'will display the earliest of the dates in the future' do
          expect(subject.earliest_release_date).
              to eq(conditional_release_date)
        end
      end

      context 'when comprised solely of dates in the past' do
        let(:parole_eligibility_date) { Date.new(2009, 1, 1) }
        let(:automatic_release_date) { Date.new(2009, 1, 11) }
        let(:conditional_release_date) { Date.new(2009, 1, 21) }

        it 'will display the most recent of the dates in the past' do
          expect(subject.earliest_release_date).
              to eq(conditional_release_date)
        end
      end
    end
  end

  describe '#sentenced?' do
    context 'with sentence detail with a release date' do
      before do
        subject.sentence = HmppsApi::SentenceDetail.from_json(
          'sentenceStartDate' => Date.new(2005, 2, 3).to_s,
          'releaseDate' => Time.zone.today.to_s)
      end

      it 'marks the offender as sentenced' do
        expect(subject.sentenced?).to be true
      end
    end

    context 'with blank sentence detail' do
      before { subject.sentence = HmppsApi::SentenceDetail.new }

      it 'marks the offender as not sentenced' do
        expect(subject.sentenced?).to be false
      end
    end
  end

  describe '#age' do
    context 'with a date of birth 50 years ago' do
      before { subject.date_of_birth = 50.years.ago }

      it 'returns 50' do
        expect(subject.age).to eq(50)
      end
    end

    context 'with a date of birth just under 50 years ago' do
      before { subject.date_of_birth = 50.years.ago + 1.day }

      it 'returns 49' do
        expect(subject.age).to eq(49)
      end
    end

    context 'with an 18th birthday in a past month' do
      before { subject.date_of_birth = '5 Jan 2001'.to_date }

      it 'returns 18' do
        Timecop.travel('19 Feb 2019') do
          expect(subject.age).to eq(18)
        end
      end
    end

    context 'with no date of birth' do
      before { subject.date_of_birth = nil }

      it 'returns nil' do
        expect(subject.age).to be_nil
      end
    end
  end

  describe '#recalled' do
    context 'when recall flag set' do
      let(:offender) { build(:offender, recall: true) }

      it 'is true' do
        expect(offender.recalled?).to eq(true)
      end
    end

    context 'when recall flag unset' do
      let(:offender) { build(:offender, recall: false) }

      it 'is false' do
        expect(offender.recalled?).to eq(false)
      end
    end
  end
end
