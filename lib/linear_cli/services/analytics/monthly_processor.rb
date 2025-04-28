# frozen_string_literal: true

module LinearCli
  module Services
    module Analytics
      # Service to process monthly data for team workload report
      class MonthlyProcessor
        # Initialize the monthly processor
        # @param workload_calculator [LinearCli::Services::Analytics::WorkloadCalculator] Calculator for workloads
        def initialize(workload_calculator = nil)
          @workload_calculator = workload_calculator || LinearCli::Services::Analytics::WorkloadCalculator.new
        end

        # Process issues data into monthly reports for a specific team
        # @param issues_data [Array<Hash>] Array of issue data for the past 6 months
        # @param team [Hash] Team data for the target team
        # @param projects_data [Array<Hash>] Array of project data
        # @return [Hash] Monthly workload reports for the specified team
        def process_monthly_team_data(issues_data, team, projects_data)
          monthly_issues = group_issues_by_month(issues_data)

          # Process data for each month
          monthly_reports = {}
          monthly_issues.each do |month_key, month_data|
            # Calculate team workload for this month's issues
            monthly_reports[month_key] = @workload_calculator.calculate_team_project_workload(
              month_data[:issues],
              team,
              projects_data
            )
            monthly_reports[month_key][:month_name] = month_data[:name]
            monthly_reports[month_key][:issue_count] = month_data[:issues].size
          end

          monthly_reports
        end

        # Process issues data into monthly reports
        # @param issues_data [Array<Hash>] Array of issue data for the past 6 months
        # @param teams_data [Array<Hash>] Array of team data
        # @param projects_data [Array<Hash>] Array of project data
        # @return [Hash] Monthly workload reports for all teams
        def process_monthly_data(issues_data, teams_data, projects_data)
          monthly_issues = group_issues_by_month(issues_data)

          # Process data for each month
          monthly_reports = {}
          monthly_issues.each do |month_key, month_data|
            # Calculate engineer workload for this month's issues
            monthly_reports[month_key] = @workload_calculator.calculate_engineer_project_workload(
              month_data[:issues],
              teams_data,
              projects_data
            )
            monthly_reports[month_key][:name] = month_data[:name]
            monthly_reports[month_key][:issue_count] = month_data[:issues].size
          end

          monthly_reports
        end

        private

        # Group issues by month for the past 6 months
        # @param issues_data [Array<Hash>] Array of issue data
        # @return [Hash] Issues grouped by month
        def group_issues_by_month(issues_data)
          monthly_issues = {}

          # Handle nil issues
          issues_data = [] if issues_data.nil?

          # Group issues by month for the past 6 months
          (0..5).each do |months_ago|
            month_date = (Time.now - (months_ago * 30 * 24 * 60 * 60))
            month_key = month_date.strftime('%Y-%m')
            month_name = month_date.strftime('%B %Y')

            # For each issue, assign it to a month based on:
            # 1. completedAt date if available
            # 2. otherwise, createdAt date
            # 3. if neither exists, use current month (extremely rare case)
            month_issues = issues_data.select do |issue|
              # Use completedAt if available, otherwise fall back to createdAt
              date_to_check = issue['completedAt'] || issue['createdAt']

              # Skip if no date exists at all (unlikely but possible)
              next false unless date_to_check

              # Place in current month if parsing fails (shouldn't happen but just in case)
              begin
                date_time = Time.parse(date_to_check)
                # Assign to month/year
                date_time.strftime('%Y-%m') == month_key
              rescue StandardError
                months_ago.zero? # If parsing fails, put in current month
              end
            end

            monthly_issues[month_key] = {
              name: month_name,
              issues: month_issues
            }
          end

          monthly_issues
        end
      end
    end
  end
end
