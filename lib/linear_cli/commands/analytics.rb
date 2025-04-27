require 'thor'
require 'tty-table'
require 'json'
require_relative '../api/client'
require_relative '../analytics/reporting'
require_relative '../analytics/display'
require_relative '../ui/table_renderer'
require_relative '../services/analytics/workload_calculator'
require_relative '../services/analytics/period_filter'
require_relative '../services/analytics/data_fetcher'

module LinearCli
  module API
    module Queries
      # GraphQL queries for analytics and reporting
      module Analytics
        # Query to list teams for reporting
        # @return [String] GraphQL query
        def self.list_teams
          <<~GRAPHQL
            query Teams {
              teams {
                nodes {
                  id
                  name
                  key
                  description
                }
              }
            }
          GRAPHQL
        end

        # Query to get all projects for reporting
        # @return [String] GraphQL query
        def self.list_projects
          <<~GRAPHQL
            query Projects {
              projects {
                nodes {
                  id
                  name
                  description
                  state
                  progress
                  labels {
                    nodes {
                      id
                      name
                    }
                  }
                  teams {
                    nodes {
                      id
                      name
                    }
                  }
                  issues {
                    nodes {
                      id
                      identifier
                    }
                  }
                }
              }
            }
          GRAPHQL
        end

        # Query to get all issues for reporting
        # @return [String] GraphQL query
        def self.list_issues
          <<~GRAPHQL
            query {
              issues(first: 100) {
                nodes {
                  id
                  identifier
                  title
                  description
                  state {
                    id
                    name
                    type
                  }
                  assignee {
                    id
                    name
                    email
                  }
                  team {
                    id
                    name
                    key
                  }
                  priority
                  project {
                    id
                    name
                  }
                  labels {
                    nodes {
                      id
                      name
                    }
                  }
                  estimate
                  startedAt
                  completedAt
                  createdAt
                  updatedAt
                }
              }
            }
          GRAPHQL
        end
      end
    end
  end

  module Commands
    # Commands related to analytics and reporting for Linear data
    class Analytics < Thor
      desc 'report', 'Generate a comprehensive report from Linear workspace data'
      long_desc <<-LONGDESC
        Generates a comprehensive report of your Linear workspace data.

        This command fetches all teams, projects, and issues from your Linear workspace
        and provides detailed analytics including:
        - Team and project counts
        - Issue distribution by status and team
        - Team completion rates

        You can output the report in table format (human-readable) or JSON format (for further processing).

        Examples:
          linear analytics report                # Output in table format
          linear analytics report --format=json  # Output in JSON format
          linear analytics engineer_workload     # Generate monthly engineer workload report
      LONGDESC
      option :format,
             type: :string,
             desc: 'Output format (json or table)',
             default: 'table',
             required: false
      def report
        format = options[:format]&.downcase || 'table'
        validate_format(format)

        client = LinearCli::API::Client.new
        data_fetcher = LinearCli::Services::Analytics::DataFetcher.new(client)

        # Fetch all required data
        teams_data = data_fetcher.fetch_teams
        projects_data = data_fetcher.fetch_projects
        issues_data = data_fetcher.fetch_issues

        # Create reporting data structure
        report_data = LinearCli::Analytics::Reporting.generate_report(
          teams_data,
          projects_data,
          issues_data
        )

        # Output based on requested format
        if format == 'json'
          puts JSON.pretty_generate(report_data)
        else
          LinearCli::Analytics::Display.display_summary_tables(report_data[:summary])
        end
      end

      desc 'engineer_workload', 'Generate a monthly report of engineer contributions by project and team'
      long_desc <<-LONGDESC
        Generates a detailed report of engineer workload across teams and projects.

        This command analyzes your Linear workspace data to show how engineers have contributed
        to projects over time. For each team and project, the report shows:
        - Each engineer who has contributed to the project
        - The percentage of their total work (measured in story points) spent on each project
        - Monthly breakdown of contributions going back 6 months

        The report provides insights into:
        - How engineers are distributing their time across projects
        - Which projects are receiving the most engineering effort
        - How team priorities have shifted over time
        - Resource allocation across the organization

        Examples:
          linear analytics engineer_workload                # Output in table format
          linear analytics engineer_workload --format=json  # Output in JSON format
      LONGDESC
      option :format,
             type: :string,
             desc: 'Output format (json or table)',
             default: 'table',
             required: false
      def engineer_workload
        format = options[:format]&.downcase || 'table'
        validate_format(format)

        client = LinearCli::API::Client.new
        data_fetcher = LinearCli::Services::Analytics::DataFetcher.new(client)

        # Get all teams
        puts 'Fetching teams data...'
        teams_data = data_fetcher.fetch_teams

        # Get all projects
        puts 'Fetching projects data...'
        projects_data = data_fetcher.fetch_projects

        # Get all issues
        puts 'Fetching issues data...'
        all_issues_data = data_fetcher.fetch_issues

        period_filter = LinearCli::Services::Analytics::PeriodFilter.new

        # Filter issues for the last 6 months
        issues_data = period_filter.filter_issues_by_period(all_issues_data, 'all')

        puts "Analyzing #{issues_data.size} issues from the past 6 months..."

        # Group issues by month for the past 6 months
        monthly_reports = process_monthly_data(issues_data, teams_data, projects_data)

        # Output based on requested format
        if format == 'json'
          puts JSON.pretty_generate(monthly_reports)
        else
          display_engineer_workload_report(monthly_reports, teams_data)
        end
      end

      private

      def validate_format(format)
        return if %w[json table].include?(format)

        raise "Invalid format: #{format}. Must be 'json' or 'table'."
      end

      def process_monthly_data(issues_data, teams_data, projects_data)
        workload_calculator = LinearCli::Services::Analytics::WorkloadCalculator.new
        monthly_issues = {}

        # Group issues by month for the past 6 months
        (0..5).each do |months_ago|
          month_date = (Time.now - (months_ago * 30 * 24 * 60 * 60))
          month_key = month_date.strftime('%Y-%m')
          month_name = month_date.strftime('%B %Y')

          # Filter issues for this month based on completion date or creation date
          monthly_issues[month_key] = {
            name: month_name,
            issues: issues_data.select do |issue|
              # Use completedAt if available, otherwise fall back to createdAt
              date_to_check = issue['completedAt'] || issue['createdAt']
              next false unless date_to_check

              date_time = Time.parse(date_to_check)
              date_time.strftime('%Y-%m') == month_key
            end
          }
        end

        # Process data for each month
        monthly_reports = {}
        monthly_issues.each do |month_key, month_data|
          # Calculate engineer workload for this month's issues
          monthly_reports[month_key] = workload_calculator.calculate_engineer_project_workload(
            month_data[:issues],
            teams_data,
            projects_data
          )
          monthly_reports[month_key][:name] = month_data[:name]
          monthly_reports[month_key][:issue_count] = month_data[:issues].size
        end

        monthly_reports
      end

      # Display the engineer workload report for monthly data
      def display_engineer_workload_report(monthly_reports, teams)
        puts "\n#{'Monthly Engineer Workload Report (Past 6 Months)'.bold}"

        # Sort months chronologically (oldest to newest)
        sorted_months = monthly_reports.keys.sort

        # For each team
        teams.each do |team|
          team_id = team['id']
          team_name = team['name']

          puts "\n#{'=' * 80}"
          puts "Team: #{team_name.bold}"
          puts "#{'=' * 80}"

          # Check if team has data in any month
          has_team_data = sorted_months.any? { |month| monthly_reports[month][team_id] }

          unless has_team_data
            puts '  No data available for this team in the past 6 months.'
            next
          end

          # Create a table showing engineers and their monthly point totals
          all_engineers = {}

          # Collect all engineers who have contributed to this team
          sorted_months.each do |month|
            next unless monthly_reports[month][team_id]

            monthly_reports[month][team_id][:engineers].each do |engineer_id, engineer|
              all_engineers[engineer_id] ||= engineer[:name]
            end
          end

          # Create rows with engineer point totals by month
          rows = []
          all_engineers.each do |engineer_id, engineer_name|
            row = [engineer_name]

            # Add point totals for each month
            sorted_months.each do |month|
              if monthly_reports[month][team_id] &&
                 monthly_reports[month][team_id][:engineers][engineer_id]
                points = monthly_reports[month][team_id][:engineers][engineer_id][:total_points]
                row << points
              else
                row << 0
              end
            end

            # Add row only if engineer has points
            rows << row if row[1..-1].sum > 0
          end

          # Sort rows by total points (highest first)
          rows = rows.sort_by { |row| -row[1..-1].sum }

          # Create headers with month names
          headers = ['Engineer']
          sorted_months.each do |month|
            headers << monthly_reports[month][:name]
          end

          # Add a total column
          headers << 'Total'
          rows.each do |row|
            row << row[1..-1].sum
          end

          # Use the centralized table renderer
          puts LinearCli::UI::TableRenderer.render_table(headers, rows)

          # For each month, show project details
          sorted_months.each do |month|
            month_name = monthly_reports[month][:name]

            # Skip if no data for this month and team
            next unless monthly_reports[month][team_id] &&
                        !monthly_reports[month][team_id][:projects].empty?

            puts "\n#{'Month:'.bold} #{month_name} (#{monthly_reports[month][:issue_count]} issues)"

            # Get team data for this month
            team_data = monthly_reports[month][team_id]

            # Display projects for this team in this month
            team_data[:projects].each do |project_id, project|
              next if project[:engineers].empty?

              puts "  #{'Project:'.bold} #{project[:name]} (#{project[:total_points]} points)"

              # List engineers who worked on this project
              project[:engineers].each do |_engineer_id, engineer|
                puts "    - #{engineer[:name]}: #{engineer[:points]} points (#{engineer[:percentage]}%)"
              end
            end
          end
        end
      end
    end
  end
end
