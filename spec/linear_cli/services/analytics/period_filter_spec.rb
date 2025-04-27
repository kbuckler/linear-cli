require 'spec_helper'

RSpec.describe LinearCli::Services::Analytics::PeriodFilter do
  let(:period_filter) { described_class.new }
  let(:current_time) { Time.new(2023, 6, 15) }

  before do
    allow(Time).to receive(:now).and_return(current_time)
  end

  describe '#filter_issues_by_period' do
    context 'when issues is nil' do
      it 'returns an empty array' do
        result = period_filter.filter_issues_by_period(nil, 'all')
        expect(result).to eq([])
      end
    end

    context 'with empty issues array' do
      it 'returns an empty array' do
        result = period_filter.filter_issues_by_period([], 'all')
        expect(result).to eq([])
      end
    end

    context 'with period all' do
      let(:six_months_ago) { (current_time - (6 * 30 * 24 * 60 * 60)).strftime('%Y-%m-%d') }
      let(:seven_months_ago) { (current_time - (7 * 30 * 24 * 60 * 60)).strftime('%Y-%m-%d') }

      let(:issues) do
        [
          { 'id' => '1', 'completedAt' => six_months_ago },
          { 'id' => '2', 'completedAt' => (current_time - (30 * 24 * 60 * 60)).strftime('%Y-%m-%d') },
          { 'id' => '3', 'completedAt' => seven_months_ago },
          { 'id' => '4', 'createdAt' => six_months_ago, 'completedAt' => nil },
          { 'id' => '5', 'createdAt' => seven_months_ago, 'completedAt' => nil }
        ]
      end

      it 'returns issues from the last 6 months' do
        result = period_filter.filter_issues_by_period(issues, 'all')
        expect(result.map { |i| i['id'] }).to match_array(%w[1 2 4])
      end

      it 'skips issues without dates' do
        issues_without_dates = [{ 'id' => '6' }]
        result = period_filter.filter_issues_by_period(issues_without_dates, 'all')
        expect(result).to be_empty
      end
    end

    context 'with period month' do
      let(:this_month) { Time.new(2023, 6, 10).strftime('%Y-%m-%d') }
      let(:last_month) { Time.new(2023, 5, 10).strftime('%Y-%m-%d') }

      let(:issues) do
        [
          { 'id' => '1', 'completedAt' => this_month },
          { 'id' => '2', 'completedAt' => last_month },
          { 'id' => '3', 'createdAt' => this_month, 'completedAt' => nil }
        ]
      end

      it 'returns issues from the current month' do
        result = period_filter.filter_issues_by_period(issues, 'month')
        expect(result.map { |i| i['id'] }).to match_array(%w[1 3])
      end
    end

    context 'with period quarter' do
      let(:this_quarter) { Time.new(2023, 6, 10).strftime('%Y-%m-%d') } # Q2
      let(:last_quarter) { Time.new(2023, 3, 10).strftime('%Y-%m-%d') } # Q1

      let(:issues) do
        [
          { 'id' => '1', 'completedAt' => this_quarter },
          { 'id' => '2', 'completedAt' => last_quarter },
          { 'id' => '3', 'createdAt' => this_quarter, 'completedAt' => nil }
        ]
      end

      it 'returns issues from the current quarter' do
        result = period_filter.filter_issues_by_period(issues, 'quarter')
        expect(result.map { |i| i['id'] }).to match_array(%w[1 3])
      end
    end

    context 'with period year' do
      let(:this_year) { Time.new(2023, 6, 10).strftime('%Y-%m-%d') }
      let(:last_year) { Time.new(2022, 6, 10).strftime('%Y-%m-%d') }

      let(:issues) do
        [
          { 'id' => '1', 'completedAt' => this_year },
          { 'id' => '2', 'completedAt' => last_year },
          { 'id' => '3', 'createdAt' => this_year, 'completedAt' => nil }
        ]
      end

      it 'returns issues from the current year' do
        result = period_filter.filter_issues_by_period(issues, 'year')
        expect(result.map { |i| i['id'] }).to match_array(%w[1 3])
      end
    end
  end

  describe 'date comparison methods' do
    describe '#same_month_and_year?' do
      it 'returns true for times in the same month and year' do
        time1 = Time.new(2023, 6, 1)
        time2 = Time.new(2023, 6, 30)
        expect(period_filter.send(:same_month_and_year?, time1, time2)).to be true
      end

      it 'returns false for times in different months' do
        time1 = Time.new(2023, 6, 1)
        time2 = Time.new(2023, 7, 1)
        expect(period_filter.send(:same_month_and_year?, time1, time2)).to be false
      end

      it 'returns false for times in different years' do
        time1 = Time.new(2023, 6, 1)
        time2 = Time.new(2022, 6, 1)
        expect(period_filter.send(:same_month_and_year?, time1, time2)).to be false
      end
    end

    describe '#same_quarter_and_year?' do
      it 'returns true for times in the same quarter and year' do
        time1 = Time.new(2023, 4, 1)  # Q2
        time2 = Time.new(2023, 6, 30) # Q2
        expect(period_filter.send(:same_quarter_and_year?, time1, time2)).to be true
      end

      it 'returns false for times in different quarters' do
        time1 = Time.new(2023, 3, 31) # Q1
        time2 = Time.new(2023, 4, 1)  # Q2
        expect(period_filter.send(:same_quarter_and_year?, time1, time2)).to be false
      end

      it 'returns false for times in different years' do
        time1 = Time.new(2023, 4, 1) # Q2 2023
        time2 = Time.new(2022, 4, 1) # Q2 2022
        expect(period_filter.send(:same_quarter_and_year?, time1, time2)).to be false
      end
    end

    describe '#same_year?' do
      it 'returns true for times in the same year' do
        time1 = Time.new(2023, 1, 1)
        time2 = Time.new(2023, 12, 31)
        expect(period_filter.send(:same_year?, time1, time2)).to be true
      end

      it 'returns false for times in different years' do
        time1 = Time.new(2023, 1, 1)
        time2 = Time.new(2022, 1, 1)
        expect(period_filter.send(:same_year?, time1, time2)).to be false
      end
    end
  end
end
