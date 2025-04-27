require 'spec_helper'

RSpec.describe LinearCli::Commands::Analytics do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double(LinearCli::API::Client) }
  let(:data_fetcher) { instance_double(LinearCli::Services::Analytics::DataFetcher) }
  let(:period_filter) { instance_double(LinearCli::Services::Analytics::PeriodFilter) }
  let(:workload_calculator) { instance_double(LinearCli::Services::Analytics::WorkloadCalculator) }
  let(:command) { described_class.new }

  before do
    allow(LinearCli::API::Client).to receive(:new).and_return(client)
    allow(LinearCli::Services::Analytics::DataFetcher).to receive(:new).with(client).and_return(data_fetcher)
    allow(LinearCli::Services::Analytics::PeriodFilter).to receive(:new).and_return(period_filter)
    allow(LinearCli::Services::Analytics::WorkloadCalculator).to receive(:new).and_return(workload_calculator)
    # Mock the output methods to prevent actual output during tests
    allow(command).to receive(:puts)
    allow(command).to receive(:display_engineer_workload_report)
    allow(command).to receive(:display_summary_workload_report)
    allow(command).to receive(:display_single_period_workload_report)
    allow(command).to receive(:display_single_period_summary_report)
  end

  describe '#engineer_workload' do
    let(:teams_data) do
      [
        {
          'id' => 'team_1',
          'name' => 'Engineering'
        }
      ]
    end

    let(:projects_data) do
      [
        {
          'id' => 'project_1',
          'name' => 'Project A'
        }
      ]
    end

    let(:issues_data) do
      [
        {
          'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
          'project' => { 'id' => 'project_1', 'name' => 'Project A' },
          'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
          'estimate' => 5,
          'completedAt' => Time.now.strftime('%Y-%m-%d')
        }
      ]
    end

    let(:workload_result) do
      {
        'team_1' => {
          name: 'Engineering',
          projects: {
            'project_1' => {
              name: 'Project A',
              total_points: 5,
              engineers: {
                'user_1' => {
                  name: 'John Doe',
                  points: 5,
                  percentage: 100.0
                }
              }
            }
          },
          engineers: {
            'user_1' => {
              name: 'John Doe',
              total_points: 5,
              projects: {
                'project_1' => {
                  name: 'Project A',
                  points: 5,
                  percentage: 100.0
                }
              }
            }
          }
        }
      }
    end

    before do
      allow(data_fetcher).to receive(:fetch_teams).and_return(teams_data)
      allow(data_fetcher).to receive(:fetch_projects).and_return(projects_data)
      allow(data_fetcher).to receive(:fetch_issues).and_return(issues_data)
      allow(period_filter).to receive(:filter_issues_by_period).and_return(issues_data)
      allow(workload_calculator).to receive(:calculate_engineer_project_workload).and_return(workload_result)
      allow(command).to receive(:process_monthly_data).and_return({})

      command.options = { format: 'table', period: 'month', view: 'detailed' }
    end

    it 'fetches all required data' do
      command.engineer_workload

      expect(data_fetcher).to have_received(:fetch_teams)
      expect(data_fetcher).to have_received(:fetch_projects)
      expect(data_fetcher).to have_received(:fetch_issues)
    end

    it 'filters issues by period' do
      command.engineer_workload

      expect(period_filter).to have_received(:filter_issues_by_period)
    end

    context 'with all period' do
      before do
        command.options = { format: 'table', period: 'all', view: 'detailed' }
      end

      it 'processes monthly data' do
        allow(command).to receive(:process_monthly_data).and_return({})

        command.engineer_workload

        expect(command).to have_received(:process_monthly_data)
        expect(workload_calculator).not_to have_received(:calculate_engineer_project_workload)
      end
    end

    context 'with specific period' do
      before do
        command.options = { format: 'table', period: 'month', view: 'detailed' }
      end

      it 'calculates workload for the period' do
        command.engineer_workload

        expect(workload_calculator).to have_received(:calculate_engineer_project_workload)
        expect(command).not_to have_received(:process_monthly_data)
      end
    end

    context 'with JSON output format' do
      before do
        command.options = { format: 'json', period: 'month', view: 'detailed' }
      end

      it 'outputs JSON' do
        expect(command).to receive(:puts).with(anything)

        command.engineer_workload
      end
    end

    context 'with different view options' do
      it 'displays detailed report for detailed view' do
        command.options = { format: 'table', period: 'month', view: 'detailed' }

        command.engineer_workload

        expect(command).to have_received(:display_single_period_workload_report)
        expect(command).not_to have_received(:display_single_period_summary_report)
      end

      it 'displays summary report for summary view' do
        command.options = { format: 'table', period: 'month', view: 'summary' }

        command.engineer_workload

        expect(command).to have_received(:display_single_period_summary_report)
        expect(command).not_to have_received(:display_single_period_workload_report)
      end
    end
  end

  describe '#report' do
    let(:teams_data) { [{ 'id' => 'team_1', 'name' => 'Team 1' }] }
    let(:projects_data) { [{ 'id' => 'project_1', 'name' => 'Project 1' }] }
    let(:issues_data) { [{ 'id' => 'issue_1', 'title' => 'Issue 1' }] }
    let(:report_data) do
      {
        summary: {
          teams: { count: 1 },
          projects: { count: 1 },
          issues: { count: 1 }
        }
      }
    end

    before do
      allow(data_fetcher).to receive(:fetch_teams).and_return(teams_data)
      allow(data_fetcher).to receive(:fetch_projects).and_return(projects_data)
      allow(data_fetcher).to receive(:fetch_issues).and_return(issues_data)
      allow(LinearCli::Analytics::Reporting).to receive(:generate_report).and_return(report_data)
      allow(LinearCli::Analytics::Display).to receive(:display_summary_tables)

      command.options = { format: 'table' }
    end

    it 'generates a report with the fetched data' do
      command.report

      expect(data_fetcher).to have_received(:fetch_teams)
      expect(data_fetcher).to have_received(:fetch_projects)
      expect(data_fetcher).to have_received(:fetch_issues)
      expect(LinearCli::Analytics::Reporting).to have_received(:generate_report).with(teams_data, projects_data,
                                                                                      issues_data)
    end

    context 'with table format' do
      it 'displays the summary tables' do
        command.report

        expect(LinearCli::Analytics::Display).to have_received(:display_summary_tables).with(report_data[:summary])
      end
    end

    context 'with JSON format' do
      before do
        command.options = { format: 'json' }
      end

      it 'outputs the report as JSON' do
        expect(command).to receive(:puts).with(JSON.pretty_generate(report_data))

        command.report
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

    describe '#validate_period' do
      it 'accepts valid periods' do
        expect { command.send(:validate_period, 'all') }.not_to raise_error
        expect { command.send(:validate_period, 'month') }.not_to raise_error
        expect { command.send(:validate_period, 'quarter') }.not_to raise_error
        expect { command.send(:validate_period, 'year') }.not_to raise_error
      end

      it 'raises an error for invalid periods' do
        expect { command.send(:validate_period, 'invalid') }.to raise_error(/Invalid period/)
      end
    end

    describe '#validate_view' do
      it 'accepts valid views' do
        expect { command.send(:validate_view, 'detailed') }.not_to raise_error
        expect { command.send(:validate_view, 'summary') }.not_to raise_error
      end

      it 'raises an error for invalid views' do
        expect { command.send(:validate_view, 'invalid') }.to raise_error(/Invalid view/)
      end
    end
  end
end
