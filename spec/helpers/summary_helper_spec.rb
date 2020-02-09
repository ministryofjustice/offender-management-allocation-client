require 'rails_helper'

RSpec.describe SummaryHelper do
  it "says schedule is tomorrow if arrival date is today" do
    # '18/11/2019' was a Monday. We need to travel to a weekday
    # as otherwise this will fail if run over the weekend
    Timecop.travel(Date.parse('18/11/2019')) do
      sched = delius_schedule_for(Time.zone.today)
      expect(sched).to eq('Tomorrow')
    end
  end

  it "says schedule is today if arrival date is yesterday" do
    # '19/11/2019' was a Tuesday. We need to travel to a weekday
    # as otherwise this will fail if run over the weekend
    Timecop.travel(Date.parse('19/11/2019')) do
      sched = delius_schedule_for(Time.zone.today - 1.day)
      expect(sched).to eq('Today')
    end
  end

  it "says monday if today is not mon-fri" do
    # '16/11/2019' was a saturday
    Timecop.travel(Date.parse('16/11/2019')) do
      sched = delius_schedule_for(Time.zone.today)
      expect(sched).to eq('Monday')

      sched = delius_schedule_for(Time.zone.today - 1.day)
      expect(sched).to eq('Monday')
    end
  end
end
