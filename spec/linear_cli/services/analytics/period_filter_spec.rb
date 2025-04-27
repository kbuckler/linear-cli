require 'spec_helper'

RSpec.describe LinearCli::Services::Analytics::PeriodFilter do
  let(:period_filter) { described_class.new }
  let(:current_time) { Time.new(2023, 6, 15) }
  let(:current_date) { Date.new(2023, 6, 15) }

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
      # Calculate exactly 6 months ago using Date's << operator
      let(:six_months_ago_date) { current_date << described_class::MONTHS_LOOKBACK }
      let(:six_months_ago) { six_months_ago_date.strftime('%Y-%m-%d') }
      let(:one_day_before_cutoff) { (six_months_ago_date - 1).strftime('%Y-%m-%d') }
      let(:one_day_after_cutoff) { (six_months_ago_date + 1).strftime('%Y-%m-%d') }

      let(:issues) do
        [
          { 'id' => '1', 'completedAt' => six_months_ago },
          { 'id' => '2', 'completedAt' => (current_time - (30 * 24 * 60 * 60)).strftime('%Y-%m-%d') },
          { 'id' => '3', 'completedAt' => one_day_before_cutoff },
          { 'id' => '4', 'createdAt' => one_day_after_cutoff, 'completedAt' => nil },
          { 'id' => '5', 'createdAt' => one_day_before_cutoff, 'completedAt' => nil }
        ]
      end

      it 'returns issues from the last 6 months' do
        result = period_filter.filter_issues_by_period(issues, 'all')
        expect(result.map { |i| i['id'] }).to match_array(%w[1 2 4])
      end

      it 'includes issues exactly at the cutoff date' do
        issues_at_cutoff = [{ 'id' => '6', 'completedAt' => six_months_ago }]
        result = period_filter.filter_issues_by_period(issues_at_cutoff, 'all')
        expect(result.map { |i| i['id'] }).to match_array(%w[6])
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
      let(:next_month) { Time.new(2023, 7, 10).strftime('%Y-%m-%d') }
      let(:same_month_last_year) { Time.new(2022, 6, 10).strftime('%Y-%m-%d') }

      let(:issues) do
        [
          { 'id' => '1', 'completedAt' => this_month },
          { 'id' => '2', 'completedAt' => last_month },
          { 'id' => '3', 'createdAt' => this_month, 'completedAt' => nil },
          { 'id' => '4', 'completedAt' => next_month },
          { 'id' => '5', 'completedAt' => same_month_last_year }
        ]
      end

      it 'returns issues from the current month' do
        result = period_filter.filter_issues_by_period(issues, 'month')
        expect(result.map { |i| i['id'] }).to match_array(%w[1 3])
      end
    end

    context 'with period quarter' do
      let(:this_quarter_start) { Time.new(2023, 4, 1).strftime('%Y-%m-%d') }  # Q2 start
      let(:this_quarter_end) { Time.new(2023, 6, 30).strftime('%Y-%m-%d') }   # Q2 end
      let(:last_quarter) { Time.new(2023, 3, 10).strftime('%Y-%m-%d') }       # Q1
      let(:next_quarter) { Time.new(2023, 7, 10).strftime('%Y-%m-%d') }       # Q3
      let(:same_quarter_last_year) { Time.new(2022, 5, 10).strftime('%Y-%m-%d') } # Q2 previous year

      let(:issues) do
        [
          { 'id' => '1', 'completedAt' => this_quarter_start },
          { 'id' => '2', 'completedAt' => this_quarter_end },
          { 'id' => '3', 'completedAt' => last_quarter },
          { 'id' => '4', 'createdAt' => this_quarter_end, 'completedAt' => nil },
          { 'id' => '5', 'completedAt' => next_quarter },
          { 'id' => '6', 'completedAt' => same_quarter_last_year }
        ]
      end

      it 'returns issues from the current quarter' do
        result = period_filter.filter_issues_by_period(issues, 'quarter')
        expect(result.map { |i| i['id'] }).to match_array(%w[1 2 4])
      end
    end

    context 'with period year' do
      let(:beginning_of_year) { Time.new(2023, 1, 1).strftime('%Y-%m-%d') }
      let(:end_of_year) { Time.new(2023, 12, 31).strftime('%Y-%m-%d') }
      let(:last_year) { Time.new(2022, 6, 10).strftime('%Y-%m-%d') }
      let(:next_year) { Time.new(2024, 1, 1).strftime('%Y-%m-%d') }

      let(:issues) do
        [
          { 'id' => '1', 'completedAt' => beginning_of_year },
          { 'id' => '2', 'completedAt' => end_of_year },
          { 'id' => '3', 'createdAt' => Time.new(2023, 6, 15).strftime('%Y-%m-%d'), 'completedAt' => nil },
          { 'id' => '4', 'completedAt' => last_year },
          { 'id' => '5', 'completedAt' => next_year }
        ]
      end

      it 'returns issues from the current year' do
        result = period_filter.filter_issues_by_period(issues, 'year')
        expect(result.map { |i| i['id'] }).to match_array(%w[1 2 3])
      end
    end

    context 'with invalid date formats' do
      let(:issues_with_invalid_dates) do
        [
          { 'id' => '1', 'completedAt' => 'not-a-date' },
          { 'id' => '2', 'completedAt' => '2023-13-45' }, # Invalid month/day
          { 'id' => '3', 'completedAt' => '2023/06/15' }, # Valid but different format
          { 'id' => '4', 'createdAt' => '2023-06-15', 'completedAt' => nil } # Valid date
        ]
      end

      it 'skips issues with invalid date formats' do
        # Only include the warning in tests if Rails is defined
        expect(Rails.logger).to receive(:warn).with(/Invalid date format/).at_least(:once) if defined?(Rails)

        result = period_filter.filter_issues_by_period(issues_with_invalid_dates, 'month')
        expect(result.map { |i| i['id'] }).to include('4')
        expect(result.map { |i| i['id'] }).to include('3') # Should be parsed correctly
        expect(result.map { |i| i['id'] }).not_to include('1', '2')
      end
    end

    context 'with unknown period' do
      let(:issues) do
        [
          { 'id' => '1', 'completedAt' => '2023-06-15' },
          { 'id' => '2', 'completedAt' => '2023-05-15' }
        ]
      end

      it 'returns all issues' do
        result = period_filter.filter_issues_by_period(issues, 'unknown_period')
        expect(result).to eq(issues)
      end
    end
  end

  describe 'private methods' do
    describe '#extract_date_to_check' do
      it 'prioritizes completedAt over createdAt' do
        issue = { 'completedAt' => '2023-06-15', 'createdAt' => '2023-01-01' }
        expect(period_filter.send(:extract_date_to_check, issue)).to eq('2023-06-15')
      end

      it 'falls back to createdAt when completedAt is nil' do
        issue = { 'completedAt' => nil, 'createdAt' => '2023-01-01' }
        expect(period_filter.send(:extract_date_to_check, issue)).to eq('2023-01-01')
      end

      it 'returns nil when neither completedAt nor createdAt exists' do
        issue = { 'id' => '123' }
        expect(period_filter.send(:extract_date_to_check, issue)).to be_nil
      end
    end

    describe '#calculate_cutoff_date' do
      it 'calculates exactly 6 months ago' do
        date = Date.new(2023, 6, 15)
        expected_date = (date << described_class::MONTHS_LOOKBACK).strftime('%Y-%m-%d')
        expect(period_filter.send(:calculate_cutoff_date, current_time)).to eq(expected_date)
      end

      it 'handles month rollover correctly' do
        jan_time = Time.new(2023, 1, 31) # January 31
        result = period_filter.send(:calculate_cutoff_date, jan_time)

        # Using Date's << operator handles month length differences automatically
        # So 6 months before Jan 31 should be July 31 of previous year
        expect(result).to eq('2022-07-31')
      end
    end

    describe '#quarter_from_month' do
      it 'returns correct quarter for each month' do
        expect(period_filter.send(:quarter_from_month, 1)).to eq(1)  # Jan = Q1
        expect(period_filter.send(:quarter_from_month, 3)).to eq(1)  # Mar = Q1
        expect(period_filter.send(:quarter_from_month, 4)).to eq(2)  # Apr = Q2
        expect(period_filter.send(:quarter_from_month, 6)).to eq(2)  # Jun = Q2
        expect(period_filter.send(:quarter_from_month, 7)).to eq(3)  # Jul = Q3
        expect(period_filter.send(:quarter_from_month, 9)).to eq(3)  # Sep = Q3
        expect(period_filter.send(:quarter_from_month, 10)).to eq(4) # Oct = Q4
        expect(period_filter.send(:quarter_from_month, 12)).to eq(4) # Dec = Q4
      end
    end

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
