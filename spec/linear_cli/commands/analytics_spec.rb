# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LinearCli::Commands::Analytics do
  let(:command) { described_class.new }
  let(:client) { instance_double(LinearCli::API::Client) }
  let(:data_fetcher) { instance_double(LinearCli::Services::Analytics::DataFetcher) }
  let(:period_filter) { instance_double(LinearCli::Services::Analytics::PeriodFilter) }
  let(:monthly_processor) { instance_double(LinearCli::Services::Analytics::MonthlyProcessor) }
  let(:teams_data) { [{ 'id' => 'team_1', 'name' => 'Engineering' }] }
  let(:projects_data) { [{ 'id' => 'project_1', 'name' => 'Project 1' }] }
  let(:issues_data) { [{ 'id' => 'issue_1', 'title' => 'Issue 1' }] }
  let(:all_issues_data) { [{ 'id' => 'issue_1', 'title' => 'Issue 1' }] }
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

    # Mock period filtering
    allow(period_filter).to receive(:filter_issues_by_period).and_return(issues_data)

    # Mock monthly processing
    allow(monthly_processor).to receive(:process_monthly_team_data).and_return(monthly_reports)

    # Mock reporting
    allow(LinearCli::Analytics::Reporting).to receive(:generate_report).and_return(report_data)
    allow(LinearCli::Analytics::Display).to receive(:display_summary_tables)

    # Mock command methods
    allow(command).to receive(:puts)
    allow(command).to receive(:display_team_workload_report)
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

    it 'processes monthly team data' do
      command.team_workload
      expect(monthly_processor).to have_received(:process_monthly_team_data).with(issues_data, teams_data.first, projects_data)
    end

    context 'with table format' do
      before do
        command.options = { format: 'table', team: 'Engineering' }
      end

      it 'displays the team workload report' do
        command.team_workload
        expect(command).to have_received(:display_team_workload_report).with(monthly_reports, teams_data.first)
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
        allow(data_fetcher).to receive(:fetch_team_by_name).and_return(nil)
      end

      it 'displays an error and exits' do
        expect(command).to receive(:puts).with("Error: Team 'Engineering' not found")
        expect(command).to receive(:exit).with(1)
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
end
