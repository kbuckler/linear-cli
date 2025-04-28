# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LinearCli::Commands::Analytics do
  let(:command) { described_class.new }
  let(:client) { instance_double(LinearCli::API::Client) }
  let(:data_fetcher) { instance_double(LinearCli::Services::Analytics::DataFetcher) }
  let(:period_filter) { instance_double(LinearCli::Services::Analytics::PeriodFilter) }
  let(:monthly_processor) { instance_double(LinearCli::Services::Analytics::MonthlyProcessor) }
  let(:teams_data) { [{ 'id' => 'team_1', 'name' => 'Engineering' }] }
  let(:team_data) do
    {
      'id' => 'team_1',
      'name' => 'Engineering',
      'key' => 'ENG',
      'description' => 'Engineering team',
      'projects' => { 'nodes' => projects_data },
      'issues' => { 'nodes' => issues_data }
    }
  end
  let(:projects_data) { [{ 'id' => 'project_1', 'name' => 'Project 1' }] }
  let(:issues_data) { [{ 'id' => 'issue_1', 'title' => 'Issue 1' }] }
  let(:all_issues_data) { [{ 'id' => 'issue_1', 'title' => 'Issue 1' }] }
  let(:filtered_issues_data) { [{ 'id' => 'issue_1', 'title' => 'Issue 1' }] }
  let(:monthly_reports) { { '2023-01' => { name: 'January 2023', issue_count: 5 } } }
  let(:report_data) do
    {
      summary: {
        teams_count: 1,
        projects_count: 2,
        issues_count: 10
      }
    }
  end

  before do
    # Mock dependencies
    allow(LinearCli::API::Client).to receive(:new).and_return(client)
    allow(LinearCli::Services::Analytics::DataFetcher).to receive(:new).and_return(data_fetcher)
    allow(LinearCli::Services::Analytics::PeriodFilter).to receive(:new).and_return(period_filter)
    allow(LinearCli::Services::Analytics::MonthlyProcessor).to receive(:new).and_return(monthly_processor)

    # Mock data fetching
    allow(data_fetcher).to receive(:fetch_teams).and_return(teams_data)
    allow(data_fetcher).to receive(:fetch_projects).and_return(projects_data)
    allow(data_fetcher).to receive(:fetch_issues).and_return(issues_data)
    allow(data_fetcher).to receive(:fetch_team_by_name).and_return(teams_data.first)
    allow(data_fetcher).to receive(:fetch_team_workload_data).and_return(team_data)

    # Mock period filtering
    allow(period_filter).to receive(:filter_issues_by_period).and_return(filtered_issues_data)

    # Mock monthly processing
    allow(monthly_processor).to receive(:process_monthly_team_data).and_return(monthly_reports)

    # Mock reporting
    allow(LinearCli::Analytics::Reporting).to receive(:generate_report).and_return(report_data)
    allow(LinearCli::Analytics::Display).to receive(:display_summary_tables)

    # Mock command methods
    allow(command).to receive(:puts)
    allow(command).to receive(:display_team_workload_report)
    allow(command).to receive(:exit)
  end

  describe '#report' do
    context 'with default format (table)' do
      it 'generates a report with analytics data' do
        command.report

        expect(LinearCli::Analytics::Reporting).to have_received(:generate_report)
          .with(teams_data, projects_data, issues_data)
        expect(LinearCli::Analytics::Display).to have_received(:display_summary_tables)
          .with(report_data[:summary])
      end
    end

    context 'with JSON format' do
      before do
        command.options = { format: 'json' }
      end

      it 'outputs report as JSON' do
        expect(command).to receive(:puts).with(JSON.pretty_generate(report_data))
        command.report
      end
    end

    context 'with invalid format' do
      before do
        command.options = { format: 'invalid' }
      end

      it 'raises an error' do
        expect { command.report }.to raise_error(/Invalid format/)
      end
    end
  end

  describe '#team_workload' do
    before do
      command.options = { team: 'Engineering' }
    end

    it 'fetches team by name' do
      command.team_workload
      expect(data_fetcher).to have_received(:fetch_team_by_name).with('Engineering')
    end

    it 'fetches team workload data using optimized query' do
      command.team_workload
      expect(data_fetcher).to have_received(:fetch_team_workload_data).with(teams_data.first['id'])
    end

    it 'extracts projects and issues from the nested response' do
      command.team_workload
      expect(period_filter).to have_received(:filter_issues_by_period).with(issues_data, 'all')
    end

    it 'processes monthly team data with the extracted data' do
      command.team_workload
      expect(monthly_processor).to have_received(:process_monthly_team_data).with(filtered_issues_data, team_data, projects_data)
    end

    context 'with table format' do
      before do
        command.options = { format: 'table', team: 'Engineering' }
      end

      it 'displays the team workload report' do
        command.team_workload
        expect(command).to have_received(:display_team_workload_report).with(monthly_reports, team_data)
      end
    end

    context 'with JSON output format' do
      before do
        command.options = { format: 'json', team: 'Engineering' }
      end

      it 'outputs JSON' do
        expect(command).to receive(:puts).with(JSON.pretty_generate(monthly_reports))
        command.team_workload
      end
    end

    context 'with invalid format' do
      before do
        command.options = { format: 'invalid', team: 'Engineering' }
      end

      it 'raises an error' do
        expect { command.team_workload }.to raise_error(/Invalid format/)
      end
    end

    context 'when team not found' do
      before do
        # Properly set up the test for the team not found scenario
        allow(data_fetcher).to receive(:fetch_team_by_name).with('Engineering').and_return(nil)
        # Skip subsequent calls
        allow(data_fetcher).to receive(:fetch_team_workload_data).with(anything).and_return(nil)
      end

      it 'displays an error message and returns early' do
        expect(command).to receive(:puts).with("Error: Team 'Engineering' not found")
        # In test mode, it returns early instead of exiting
        command.team_workload
      end
    end

    context 'when team workload data cannot be fetched' do
      before do
        # Set up minimum valid responses to prevent nil errors
        allow(data_fetcher).to receive(:fetch_team_workload_data).with(anything).and_return({
                                                                                              'id' => 'team_1',
                                                                                              'name' => 'Engineering',
                                                                                              'projects' => nil,
                                                                                              'issues' => nil
                                                                                            })
      end

      it 'displays an error message and returns early' do
        expect(command).to receive(:puts).with("Error: Could not fetch workload data for team 'Engineering'")
        # In test mode, it returns early instead of exiting
        command.team_workload
      end
    end
  end

  describe 'validation methods' do
    describe '#validate_format' do
      it 'accepts valid formats' do
        expect { command.send(:validate_format, 'json') }.not_to raise_error
        expect { command.send(:validate_format, 'table') }.not_to raise_error
      end

      it 'raises an error for invalid formats' do
        expect { command.send(:validate_format, 'invalid') }.to raise_error(/Invalid format/)
      end
    end
  end

  describe 'helper methods' do
    describe '#find_contributor_id_by_name' do
      let(:contributors) do
        {
          'user1' => { name: 'John Doe' },
          'user2' => { name: 'Jane Smith' }
        }
      end

      it 'finds a contributor ID by name' do
        expect(command.send(:find_contributor_id_by_name, 'John Doe', contributors)).to eq('user1')
        expect(command.send(:find_contributor_id_by_name, 'Jane Smith', contributors)).to eq('user2')
      end

      it 'returns nil for non-existent names' do
        expect(command.send(:find_contributor_id_by_name, 'Unknown Person', contributors)).to be_nil
      end

      it 'handles the Unassigned special case' do
        expect(command.send(:find_contributor_id_by_name, 'Unassigned', contributors)).to eq('unassigned')
      end
    end

    describe '#project_id_from_name' do
      let(:projects) do
        {
          'proj1' => { name: 'Project A' },
          'proj2' => { name: 'Project B' }
        }
      end

      it 'finds a project ID by name' do
        expect(command.send(:project_id_from_name, 'Project A', projects)).to eq('proj1')
        expect(command.send(:project_id_from_name, 'Project B', projects)).to eq('proj2')
      end

      it 'returns nil for non-existent projects' do
        expect(command.send(:project_id_from_name, 'Unknown Project', projects)).to be_nil
      end

      it 'handles the No Project special case' do
        expect(command.send(:project_id_from_name, 'No Project', projects)).to eq('no_project')
      end
    end
  end

  describe 'display methods' do
    describe '#display_team_workload_report' do
      let(:team) do
        { 'id' => 'team_1', 'name' => 'Engineering' }
      end

      let(:monthly_reports) do
        {
          '2023-01' => {
            month_name: 'January 2023',
            issue_count: 5,
            id: 'team_1',
            name: 'Engineering',
            contributors: {
              'user_1' => {
                name: 'John Doe',
                total_points: 10,
                issues_count: 2,
                projects: {
                  'project_1' => {
                    name: 'Project A',
                    points: 7,
                    issues_count: 1,
                    percentage: 70.0
                  },
                  'project_2' => {
                    name: 'Project B',
                    points: 3,
                    issues_count: 1,
                    percentage: 30.0
                  }
                }
              },
              'unassigned' => {
                name: 'Unassigned',
                total_points: 5,
                issues_count: 3,
                projects: {
                  'project_1' => {
                    name: 'Project A',
                    points: 5,
                    issues_count: 3,
                    percentage: 100.0
                  }
                }
              }
            },
            projects: {
              'project_1' => {
                name: 'Project A',
                total_points: 12,
                issues_count: 4,
                contributors: {
                  'user_1' => {
                    name: 'John Doe',
                    points: 7,
                    issues_count: 1,
                    percentage: 58.33
                  },
                  'unassigned' => {
                    name: 'Unassigned',
                    points: 5,
                    issues_count: 3,
                    percentage: 41.67
                  }
                }
              },
              'project_2' => {
                name: 'Project B',
                total_points: 3,
                issues_count: 1,
                contributors: {
                  'user_1' => {
                    name: 'John Doe',
                    points: 3,
                    issues_count: 1,
                    percentage: 100.0
                  }
                }
              }
            }
          }
        }
      end

      before do
        # Force the puts method to not actually output anything during tests
        allow(command).to receive(:puts)

        # Mock table renderer for test output
        allow(LinearCli::UI::TableRenderer).to receive(:render_table).and_return('Mock table')

        # Required because this is a private method
        allow(command).to receive(:display_team_workload_report).and_call_original
      end

      it 'executes without raising any errors' do
        expect { command.send(:display_team_workload_report, monthly_reports, team) }.not_to raise_error
      end
    end
  end
end
