require 'rails_helper'

describe Nomis::OffenderSummary do
  describe '#earliest_release_date' do
    context 'with blank sentence detail' do
      before { subject.sentence = Nomis::SentenceDetail.new }

      it 'responds with no earliest release date' do
        expect(subject.earliest_release_date).to be_nil
      end
    end

    context 'when main dates are missing' do
      let(:today_plus1) { Time.zone.today + 1.day }

      context 'with just the sentence expiry date' do
        before do
          subject.sentence = Nomis::SentenceDetail.new(sentence_expiry_date: today_plus1)
        end

        it 'uses the SED' do
          expect(subject.earliest_release_date).to eq(today_plus1)
        end
      end

      context 'with many dates' do
        before do
          subject.sentence = Nomis::SentenceDetail.new(sentence_expiry_date: sentence_expiry_date,
                                                       licence_expiry_date: licence_expiry_date,
                                                       nomis_post_recall_release_date: post_recall_release_date,
                                                       actual_parole_date: actual_parole_date)
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
        subject.sentence = Nomis::SentenceDetail.new(
          sentence_start_date: Date.new(2005, 2, 3),
          parole_eligibility_date: parole_eligibility_date,
          conditional_release_date: conditional_release_date)
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
    describe 'a determinate sentence' do
      before {
        subject.inprisonment_status = 'SENT03'
      }

      context 'with the required dates' do
        before  do
          subject.sentence = Nomis::SentenceDetail.new(
            sentence_start_date: Date.new(2005, 2, 3),
            automatic_release_date: Time.zone.tomorrow)
        end

        it 'marks the offender as sentenced' do
          expect(subject.sentenced?).to be true
        end
      end

      context 'without the required dates' do
        before  do
          subject.sentence = Nomis::SentenceDetail.new(
            sentence_start_date: Date.new(2005, 2, 3),
            tariff_date: Time.zone.tomorrow)
        end

        it 'marks the offender as not sentenced' do
          expect(subject.sentenced?).to be false
        end
      end
    end

    describe 'a indeterminate sentence' do
      before {
        subject.inprisonment_status = 'SEC93'
      }

      context 'with the required dates' do
        before  do
          subject.sentence = Nomis::SentenceDetail.new(
            sentence_start_date: Date.new(2005, 2, 3),
            tariff_date: Time.zone.tomorrow)
        end

        it 'marks the offender as sentenced' do
          expect(subject.sentenced?).to be true
        end
      end

      context 'without the required dates' do
        before  do
          subject.sentence = Nomis::SentenceDetail.new(
            sentence_start_date: Date.new(2005, 2, 3),
            home_detention_curfew_eligibility_date: Time.zone.tomorrow)
        end

        it 'marks the offender as not sentenced' do
          expect(subject.sentenced?).to be false
        end
      end
    end

    describe 'a recalled sentence' do
      before do
        subject.inprisonment_status = 'FTR_ORA'
      end

      context 'with the required dates' do
        before do
          subject.sentence = Nomis::SentenceDetail.new(
            sentence_start_date: Date.new(2005, 2, 3),
            nomis_post_recall_release_date: Time.zone.tomorrow)
        end

        it 'marks the offender as sentenced' do
          expect(subject.sentenced?).to be true
        end
      end

      context 'without the required dates' do
        before do
          subject.sentence = Nomis::SentenceDetail.new(
            sentence_start_date: Date.new(2005, 2, 3),
            tariff_date: Time.zone.tomorrow)
        end

        it 'marks the offender as not sentenced' do
          expect(subject.sentenced?).to be false
        end
      end
    end

    describe 'no sentence information' do
      context 'with blank sentence detail' do
        before { subject.sentence = Nomis::SentenceDetail.new }

        it 'marks the offender as not sentenced' do
          expect(subject.sentenced?).to be false
        end
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
      Timecop.travel('19 Feb 2020') do
        before { subject.date_of_birth = '5 Jan 2002'.to_date }

        it 'returns 18' do
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
end
