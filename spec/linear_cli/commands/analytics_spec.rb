# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LinearCli::Commands::Analytics do
  let(:command) { described_class.new }
  let(:client) { instance_double(LinearCli::API::Client) }
  let(:data_fetcher) { instance_double(LinearCli::Services::Analytics::DataFetcher) }
  let(:period_filter) { instance_double(LinearCli::Services::Analytics::PeriodFilter) }
  let(:monthly_processor) { instance_double(LinearCli::Services::Analytics::MonthlyProcessor) }
  let(:workload_calculator) { instance_double(LinearCli::Services::Analytics::WorkloadCalculator) }
  let(:teams_data) do
    [
      {
        'id' => 'team_1',
        'name' => 'Engineering',
        'key' => 'ENG',
        'description' => 'Engineering team'
      },
      {
        'id' => 'team_2',
        'name' => 'Product',
        'key' => 'PRD',
        'description' => 'Product team'
      }
    ]
  end
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
  let(:projects_data) do
    [
      {
        'id' => 'project_1',
        'name' => 'Project A',
        'state' => 'started',
        'description' => 'First project',
        'teams' => {
          'nodes' => [
            { 'id' => 'team_1', 'name' => 'Engineering' }
          ]
        }
      },
      {
        'id' => 'project_2',
        'name' => 'Project B',
        'state' => 'completed',
        'description' => 'Second project',
        'teams' => {
          'nodes' => [
            { 'id' => 'team_2', 'name' => 'Product' }
          ]
        }
      }
    ]
  end
  let(:issues_data) do
    [
      {
        'id' => 'issue_1',
        'title' => 'Issue 1',
        'createdAt' => '2023-01-01T00:00:00Z',
        'updatedAt' => '2023-01-10T00:00:00Z',
        'state' => {
          'name' => 'Done'
        },
        'team' => {
          'name' => 'Engineering'
        },
        'assignee' => {
          'name' => 'John Doe'
        },
        'description' => 'First issue description'
      },
      {
        'id' => 'issue_2',
        'title' => 'Issue 2',
        'createdAt' => '2023-02-01T00:00:00Z',
        'updatedAt' => '2023-02-10T00:00:00Z',
        'state' => {
          'name' => 'In Progress'
        },
        'team' => {
          'name' => 'Product'
        },
        'assignee' => nil,
        'description' => nil
      }
    ]
  end
  let(:filtered_issues_data) { [issues_data.first] }
  let(:monthly_reports) { { '2023-01' => { month_name: 'January 2023', issue_count: 5 } } }
  let(:report_data) do
    {
      summary: {
        teams_count: 2,
        projects_count: 2,
        issues_count: 2
      },
      teams: teams_data,
      projects: projects_data,
      issues: issues_data
    }
  end
  let(:team_workload_data) do
    {
      'projects' => { 'nodes' => projects_data },
      'issues' => { 'nodes' => issues_data }
    }
  end

  before do
    # Mock dependencies
    allow(LinearCli::API::Client).to receive(:new).and_return(client)
    allow(LinearCli::Services::Analytics::DataFetcher).to receive(:new).and_return(data_fetcher)
    allow(LinearCli::Services::Analytics::PeriodFilter).to receive(:new).and_return(period_filter)
    allow(LinearCli::Services::Analytics::MonthlyProcessor).to receive(:new).and_return(monthly_processor)
    allow(LinearCli::Services::Analytics::WorkloadCalculator).to receive(:new).and_return(workload_calculator)

    # Mock data fetching
    allow(data_fetcher).to receive(:fetch_teams).and_return(teams_data)
    allow(data_fetcher).to receive(:fetch_projects).and_return(projects_data)
    allow(data_fetcher).to receive(:fetch_issues).and_return(issues_data)
    allow(data_fetcher).to receive(:fetch_team_by_name).and_return(teams_data.first)
    allow(data_fetcher).to receive(:fetch_team_workload_data).and_return(team_workload_data)
    allow(data_fetcher).to receive(:fetch_team_data).and_return(team_data)

    # Mock period filtering
    allow(period_filter).to receive(:filter_issues_by_period).and_return(filtered_issues_data)

    # Mock monthly processing
    allow(monthly_processor).to receive(:process_monthly_team_data).and_return(monthly_reports)

    # Mock workload calculator
    allow(workload_calculator).to receive(:calculate_monthly_workload).and_return(
      {
        '2023-04' => {
          month_name: 'April 2023',
          contributors: {
            'user_1' => {
              name: 'John Doe',
              total_points: 10,
              issues_count: 2
            }
          }
        }
      }
    )

    # Mock reporting
    allow(LinearCli::Analytics::Reporting).to receive(:generate_report).and_return(report_data)
    allow(LinearCli::Analytics::Display).to receive(:display_summary_tables)

    # Mock command methods
    allow(command).to receive(:puts)
    allow(command).to receive(:display_team_workload_report)
    allow(command).to receive(:display_teams_list)
    allow(command).to receive(:display_projects_list)
    allow(command).to receive(:display_most_recent_issue)
    allow(command).to receive(:display_workload_summary)
    allow(command).to receive(:exit)

    # Mock UI components
    allow(LinearCli::UI::TableRenderer).to receive(:render_table).and_return('Mocked table content')
  end

  describe '#report' do
    context 'with default format (table)' do
      it 'generates a report with analytics data' do
        command.report

        expect(LinearCli::Analytics::Reporting).to have_received(:generate_report)
          .with(teams_data, projects_data, issues_data)
        # Don't test exact string formatting since it varies with ANSI codes
        expect(command).to have_received(:puts).at_least(4).times
        expect(command).to have_received(:display_teams_list).with(teams_data).once
        expect(command).to have_received(:display_projects_list).with(projects_data).once
        expect(command).to have_received(:display_most_recent_issue).with(issues_data).once
        expect(command).to have_received(:display_workload_summary)
          .with(teams_data, data_fetcher, period_filter, workload_calculator).once
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
      command.options = { period: 'all', detailed: false }
      allow(LinearCli::Services::Analytics::WorkloadCalculator).to receive(:new).and_return(
        instance_double(LinearCli::Services::Analytics::WorkloadCalculator,
                        calculate_monthly_workload: monthly_reports,
                        calculate_project_workload: monthly_reports)
      )
      allow(data_fetcher).to receive(:fetch_team_data).and_return(team_data)
    end

    it 'fetches team by name' do
      command.team_workload('Engineering')
      expect(data_fetcher).to have_received(:fetch_team_data).with('Engineering')
    end

    it 'fetches team workload data using optimized query' do
      command.team_workload('Engineering')
      expect(data_fetcher).to have_received(:fetch_team_workload_data).with(team_data['id'])
    end

    it 'extracts projects and issues from the nested response' do
      command.team_workload('Engineering')
      expect(period_filter).to have_received(:filter_issues_by_period).with(issues_data, 'all')
    end

    it 'processes monthly team data with the extracted data' do
      command.team_workload('Engineering')
      # This expectation has changed since we migrated the code
      expect(command).to have_received(:display_team_workload_report)
    end

    context 'with table format' do
      before do
        command.options = { period: 'all', detailed: false }
      end

      it 'displays the team workload report' do
        command.team_workload('Engineering')
        expect(command).to have_received(:display_team_workload_report)
      end
    end

    context 'with JSON output format' do
      before do
        command.options = { format: 'json', period: 'all', detailed: false }
      end

      it 'outputs JSON' do
        expected_output = {
          team: 'Engineering',
          period: 'all',
          monthly_data: monthly_reports,
          project_data: monthly_reports
        }
        expect(command).to receive(:puts).with(JSON.pretty_generate(expected_output))
        command.team_workload('Engineering')
      end
    end

    context 'with invalid format' do
      before do
        command.options = { format: 'invalid', period: 'all', detailed: false }
      end

      it 'raises an error' do
        expect { command.team_workload('Engineering') }.to raise_error(
          RuntimeError,
          "Invalid format: invalid. Must be 'json' or 'table'."
        )
      end
    end

    context 'when team not found' do
      before do
        # Properly set up the test for the team not found scenario
        allow(data_fetcher).to receive(:fetch_team_data).with('Engineering').and_raise(RuntimeError, "Team 'Engineering' not found")
      end

      it 'displays an error message and returns early' do
        expect(LinearCli::UI::Logger).to receive(:error).with(
          "Failed to analyze workload for team 'Engineering': Team 'Engineering' not found",
          hash_including(team: 'Engineering')
        )
        expect { command.team_workload('Engineering') }.to raise_error(RuntimeError)
      end
    end

    context 'when team workload data cannot be fetched' do
      before do
        # Set up minimum valid responses to prevent nil errors
        allow(data_fetcher).to receive(:fetch_team_workload_data).with(anything).and_return({
                                                                                              'projects' => { 'nodes' => [] },
                                                                                              'issues' => { 'nodes' => [] }
                                                                                            })
      end

      it 'handles empty data gracefully' do
        command.team_workload('Engineering')
        expect(command).to have_received(:display_team_workload_report)
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
      let(:team_name) { 'Engineering' }
      let(:monthly_data) do
        {
          '2023-01' => {
            month_name: 'January 2023',
            issue_count: 5,
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

      let(:project_data) { monthly_data }
      let(:detailed) { false }

      before do
        # Force the puts method to not actually output anything during tests
        allow(command).to receive(:puts)

        # Mock table renderer for test output
        allow(LinearCli::UI::TableRenderer).to receive(:render_table).and_return('Mock table')

        # Required because this is a private method
        allow(command).to receive(:display_team_workload_report).and_call_original
        allow(command).to receive(:display_monthly_summary)
        allow(command).to receive(:display_project_details)
        allow(LinearCli::UI::Logger).to receive(:debug)
      end

      it 'executes without raising any errors' do
        expect { command.send(:display_team_workload_report, team_name, monthly_data, project_data, detailed) }.not_to raise_error
      end
    end
  end

  # Add tests for the new display helper methods
  describe 'new display helper methods' do
    before do
      # Allow the private methods to be called directly for testing
      allow(command).to receive(:display_teams_list).and_call_original
      allow(command).to receive(:display_projects_list).and_call_original
      allow(command).to receive(:display_most_recent_issue).and_call_original
      allow(command).to receive(:display_workload_summary).and_call_original
    end

    describe '#display_teams_list' do
      it 'displays teams in a table format' do
        # Don't test exact string formatting which includes ANSI color codes
        expect(command).to receive(:puts).at_least(:twice)
        expect(LinearCli::UI::TableRenderer).to receive(:render_table)
          .with(%w[ID Name Key Description], kind_of(Array))

        command.send(:display_teams_list, teams_data)
      end

      it 'handles empty teams data' do
        # Don't test exact string formatting which includes ANSI color codes
        expect(command).to receive(:puts).at_least(:twice)

        command.send(:display_teams_list, [])
      end
    end

    describe '#display_projects_list' do
      it 'displays projects in a table format' do
        # Don't test exact string formatting which includes ANSI color codes
        expect(command).to receive(:puts).at_least(:twice)
        expect(LinearCli::UI::TableRenderer).to receive(:render_table)
          .with(%w[ID Name State Team Description], kind_of(Array))

        command.send(:display_projects_list, projects_data)
      end

      it 'handles empty projects data' do
        # Don't test exact string formatting which includes ANSI color codes
        expect(command).to receive(:puts).at_least(:twice)

        command.send(:display_projects_list, [])
      end
    end

    describe '#display_most_recent_issue' do
      it 'displays details of the most recent issue' do
        # Don't test exact string formatting which includes ANSI color codes
        expect(command).to receive(:puts).at_least(9).times

        command.send(:display_most_recent_issue, issues_data)
      end

      it 'handles empty issues data' do
        # Don't test exact string formatting which includes ANSI color codes
        expect(command).to receive(:puts).at_least(:twice)

        command.send(:display_most_recent_issue, [])
      end
    end

    describe '#display_workload_summary' do
      it 'displays workload summary for each team' do
        # Don't test exact string formatting which includes ANSI color codes
        expect(command).to receive(:puts).at_least(5).times
        expect(data_fetcher).to receive(:fetch_team_workload_data).with('team_1')
        expect(period_filter).to receive(:filter_issues_by_period).with(issues_data, 'month')
        expect(workload_calculator).to receive(:calculate_monthly_workload).with(filtered_issues_data)

        # We should expect this for each team in teams_data
        expect(data_fetcher).to receive(:fetch_team_workload_data).with('team_2')

        command.send(:display_workload_summary, teams_data, data_fetcher, period_filter, workload_calculator)
      end

      it 'handles teams with no issues' do
        empty_workload_data = { 'projects' => { 'nodes' => [] }, 'issues' => { 'nodes' => [] } }
        allow(data_fetcher).to receive(:fetch_team_workload_data).and_return(empty_workload_data)

        # Don't test exact string formatting which includes ANSI color codes
        expect(command).to receive(:puts).at_least(3).times

        command.send(:display_workload_summary, [teams_data.first], data_fetcher, period_filter, workload_calculator)
      end

      it 'handles teams with issues but none in the past month' do
        allow(period_filter).to receive(:filter_issues_by_period).and_return([])

        # Don't test exact string formatting which includes ANSI color codes
        expect(command).to receive(:puts).at_least(3).times

        command.send(:display_workload_summary, [teams_data.first], data_fetcher, period_filter, workload_calculator)
      end
    end
  end
end
