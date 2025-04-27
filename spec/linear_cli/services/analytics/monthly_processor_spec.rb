require 'spec_helper'

RSpec.describe LinearCli::Services::Analytics::MonthlyProcessor do
  let(:workload_calculator) { instance_double(LinearCli::Services::Analytics::WorkloadCalculator) }
  let(:monthly_processor) { described_class.new(workload_calculator) }

  let(:teams_data) do
    [
      { 'id' => 'team_1', 'name' => 'Engineering' }
    ]
  end

  let(:projects_data) do
    [
      { 'id' => 'project_1', 'name' => 'Project A' }
    ]
  end

  let(:current_time) { Time.new(2023, 8, 1) }
  let(:one_month_ago) { Time.new(2023, 7, 1) }
  let(:two_months_ago) { Time.new(2023, 6, 1) }

  let(:current_month_key) { current_time.strftime('%Y-%m') }
  let(:one_month_ago_key) { one_month_ago.strftime('%Y-%m') }
  let(:two_months_ago_key) { two_months_ago.strftime('%Y-%m') }

  let(:workload_result) do
    {
      'team_1' => {
        name: 'Engineering',
        projects: { 'project_1' => { name: 'Project A', total_points: 5 } },
        engineers: { 'user_1' => { name: 'John Doe', total_points: 5 } }
      }
    }
  end

  before do
    allow(Time).to receive(:now).and_return(current_time)
    allow(workload_calculator).to receive(:calculate_engineer_project_workload).and_return(workload_result)
  end

  describe '#process_monthly_data' do
    context 'with issues from multiple months' do
      let(:issues_data) do
        [
          {
            'id' => 'issue_1',
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 5,
            'completedAt' => current_time.strftime('%Y-%m-%d')
          },
          {
            'id' => 'issue_2',
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 3,
            'completedAt' => one_month_ago.strftime('%Y-%m-%d')
          },
          {
            'id' => 'issue_3',
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 8,
            'createdAt' => two_months_ago.strftime('%Y-%m-%d')
          }
        ]
      end

      it 'processes issues into monthly reports' do
        # First, let's allow calculate_engineer_project_workload to return different results for different months
        allow(workload_calculator).to receive(:calculate_engineer_project_workload) do |issues, _, _|
          # Create a different result based on the number of issues being processed
          {
            'team_1' => {
              name: 'Engineering',
              projects: { 'project_1' => { name: 'Project A', total_points: issues.size * 5 } },
              engineers: { 'user_1' => { name: 'John Doe', total_points: issues.size * 5 } }
            }
          }
        end

        result = monthly_processor.process_monthly_data(issues_data, teams_data, projects_data)

        # We should have data for all 6 months
        expect(result.keys.count).to eq(6)

        # Inspect the monthly structure and counts directly
        # Create a mapping of the expected issue counts by month
        expected_issue_counts = {
          current_month_key => 1,
          one_month_ago_key => 1,
          two_months_ago_key => 1
        }

        # Check the issue counts for each month
        expected_issue_counts.each do |month_key, count|
          expect(result).to have_key(month_key)
          expect(result[month_key][:issue_count]).to eq(count),
                                                     "Expected #{count} issues for #{month_key}, got #{result[month_key][:issue_count]}"
        end

        # Check other months have 0 issues
        (result.keys - expected_issue_counts.keys).each do |month_key|
          expect(result[month_key][:issue_count]).to eq(0)
        end
      end
    end

    context 'with nil issues data' do
      it 'handles nil issues gracefully' do
        result = monthly_processor.process_monthly_data(nil, teams_data, projects_data)

        # Should have 6 months of empty data
        expect(result.keys.count).to eq(6)
        result.each do |_month_key, month_data|
          expect(month_data[:issue_count]).to eq(0)
        end
      end
    end

    context 'with empty issues data' do
      it 'handles empty issues array' do
        result = monthly_processor.process_monthly_data([], teams_data, projects_data)

        # Should have 6 months of empty data
        expect(result.keys.count).to eq(6)
        result.each do |_month_key, month_data|
          expect(month_data[:issue_count]).to eq(0)
        end
      end
    end

    context 'with issues missing date information' do
      let(:issues_data) do
        [
          {
            'id' => 'issue_1',
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 5
            # Missing completedAt and createdAt
          }
        ]
      end

      it 'skips issues without date information' do
        result = monthly_processor.process_monthly_data(issues_data, teams_data, projects_data)

        # All months should have 0 issues
        result.each do |_month_key, month_data|
          expect(month_data[:issue_count]).to eq(0)
        end
      end
    end
  end
end
