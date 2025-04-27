require 'thor'
require 'tty-table'
require 'json'
require_relative '../api/client'
require_relative '../analytics/reporting'
require_relative '../analytics/display'
require_relative '../ui/table_renderer'

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

        # Get all teams
        teams_data = fetch_teams(client)

        # Get all projects
        projects_data = fetch_projects(client)

        # Get all issues
        issues_data = fetch_issues(client)

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

        You can filter the data by time period using the --period option.

        Examples:
          linear analytics engineer_workload                      # Output in table format
          linear analytics engineer_workload --format=json        # Output in JSON format
          linear analytics engineer_workload --period=month       # Only analyze current month's data
          linear analytics engineer_workload --period=quarter     # Only analyze current quarter's data
      LONGDESC
      option :format,
             type: :string,
             desc: 'Output format (json or table)',
             default: 'table',
             required: false
      option :period,
             type: :string,
             desc: 'Time period to analyze (month, quarter, year, all)',
             default: 'all',
             required: false
      option :view,
             type: :string,
             desc: 'View type (detailed or summary)',
             default: 'detailed',
             required: false
      def engineer_workload
        format = options[:format]&.downcase || 'table'
        period = options[:period]&.downcase || 'all'
        view = options[:view]&.downcase || 'detailed'

        validate_format(format)
        validate_period(period)
        validate_view(view)

        client = LinearCli::API::Client.new

        # Get all teams
        puts 'Fetching teams data...'
        teams_data = fetch_teams(client)

        # Get all projects
        puts 'Fetching projects data...'
        projects_data = fetch_projects(client)

        # Get all issues
        puts 'Fetching issues data...'
        all_issues_data = fetch_issues(client)

        # Filter issues by time period if needed
        issues_data = filter_issues_by_period(all_issues_data, period)

        time_desc = period == 'all' ? 'the past 6 months' : "the current #{period}"
        puts "Analyzing #{issues_data.size} issues from #{time_desc}..."

        if period == 'all'
          # Group issues by month for the past 6 months
          monthly_reports = process_monthly_data(issues_data, teams_data, projects_data)

          # Output based on requested format
          if format == 'json'
            puts JSON.pretty_generate(monthly_reports)
          elsif view == 'detailed'
            display_engineer_workload_report(monthly_reports, teams_data)
          else
            display_summary_workload_report(monthly_reports, teams_data)
          end
        else
          # Process single period data
          workload_data = calculate_engineer_project_workload(issues_data, teams_data, projects_data)

          if format == 'json'
            puts JSON.pretty_generate(workload_data)
          elsif view == 'detailed'
            display_single_period_workload_report(workload_data, teams_data, period)
          else
            display_single_period_summary_report(workload_data, teams_data, period)
          end
        end
      end

      private

      def fetch_teams(client)
        query = LinearCli::API::Queries::Analytics.list_teams
        result = client.query(query)
        result.dig('teams', 'nodes') || []
      end

      def fetch_projects(client)
        query = LinearCli::API::Queries::Analytics.list_projects
        result = client.query(query)
        result.dig('projects', 'nodes') || []
      end

      def fetch_issues(client)
        query = LinearCli::API::Queries::Analytics.list_issues
        result = client.query(query)
        result.dig('issues', 'nodes') || []
      end

      def validate_format(format)
        return if %w[json table].include?(format)

        raise "Invalid format: #{format}. Must be 'json' or 'table'."
      end

      def validate_period(period)
        return if %w[all month quarter year].include?(period)

        raise "Invalid period: #{period}. Must be 'all', 'month', 'quarter', or 'year'."
      end

      def validate_view(view)
        return if %w[detailed summary].include?(view)

        raise "Invalid view: #{view}. Must be 'detailed' or 'summary'."
      end

      def filter_issues_by_period(issues, period)
        current_time = Time.now

        if period == 'all'
          # For 'all', get the last 6 months of issues based on completion date or creation date
          six_months_ago = (Time.now - (6 * 30 * 24 * 60 * 60)).strftime('%Y-%m-%d')

          issues.select do |issue|
            # Use completedAt if available, otherwise fall back to createdAt
            date_to_check = issue['completedAt'] || issue['createdAt']
            next false unless date_to_check

            date_to_check >= six_months_ago
          end
        else
          issues.select do |issue|
            # Use completedAt if available, otherwise fall back to createdAt
            date_to_check = issue['completedAt'] || issue['createdAt']
            next false unless date_to_check

            date_time = Time.parse(date_to_check)

            case period
            when 'month'
              same_month_and_year?(date_time, current_time)
            when 'quarter'
              same_quarter_and_year?(date_time, current_time)
            when 'year'
              same_year?(date_time, current_time)
            else
              true
            end
          end
        end
      end

      def same_month_and_year?(time1, time2)
        time1.year == time2.year && time1.month == time2.month
      end

      def same_quarter_and_year?(time1, time2)
        time1.year == time2.year && ((time1.month - 1) / 3) == ((time2.month - 1) / 3)
      end

      def same_year?(time1, time2)
        time1.year == time2.year
      end

      def process_monthly_data(issues_data, teams_data, projects_data)
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
          monthly_reports[month_key] = calculate_engineer_project_workload(
            month_data[:issues],
            teams_data,
            projects_data
          )
          monthly_reports[month_key][:name] = month_data[:name]
          monthly_reports[month_key][:issue_count] = month_data[:issues].size
        end

        monthly_reports
      end

      # Calculate engineer workload across projects
      def calculate_engineer_project_workload(issues, teams, projects)
        result = {}

        # Initialize teams structure
        teams.each do |team|
          team_id = team['id']
          team_name = team['name']

          result[team_id] = {
            name: team_name,
            projects: {},
            engineers: {}
          }
        end

        # Process each issue
        issues.each do |issue|
          # Skip issues without teams or estimates
          next unless issue['team'] && issue['estimate']

          team_id = issue['team']['id']
          team_name = issue['team']['name']
          project_id = issue['project'] ? issue['project']['id'] : 'no_project'
          project_name = issue['project'] ? issue['project']['name'] : 'No Project'
          engineer_id = issue['assignee'] ? issue['assignee']['id'] : 'unassigned'
          engineer_name = issue['assignee'] ? issue['assignee']['name'] : 'Unassigned'
          points = issue['estimate'].to_i

          # Skip if points is zero
          next if points.zero?

          # Initialize project in team if needed
          result[team_id][:projects][project_id] ||= {
            name: project_name,
            total_points: 0,
            engineers: {}
          }

          # Initialize engineer in team if needed
          result[team_id][:engineers][engineer_id] ||= {
            name: engineer_name,
            total_points: 0,
            projects: {}
          }

          # Initialize engineer in project if needed
          result[team_id][:projects][project_id][:engineers][engineer_id] ||= {
            name: engineer_name,
            points: 0
          }

          # Initialize project in engineer if needed
          result[team_id][:engineers][engineer_id][:projects][project_id] ||= {
            name: project_name,
            points: 0
          }

          # Update points
          result[team_id][:projects][project_id][:total_points] += points
          result[team_id][:projects][project_id][:engineers][engineer_id][:points] += points
          result[team_id][:engineers][engineer_id][:total_points] += points
          result[team_id][:engineers][engineer_id][:projects][project_id][:points] += points
        end

        # Calculate percentages
        result.each do |_team_id, team|
          team[:engineers].each do |_engineer_id, engineer|
            engineer[:projects].each do |_project_id, project|
              project[:percentage] = ((project[:points].to_f / engineer[:total_points]) * 100).round(2)
            end
          end

          team[:projects].each do |_project_id, project|
            project[:engineers].each do |_engineer_id, engineer|
              engineer[:percentage] = ((engineer[:points].to_f / project[:total_points]) * 100).round(2)
            end
          end
        end

        result
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

          # For each month that has data for this team
          sorted_months.each do |month|
            month_name = monthly_reports[month][:name]
            issue_count = monthly_reports[month][:issue_count]

            # Skip if team has no data this month
            next unless monthly_reports[month][team_id]

            puts "\n#{'Month:'.bold} #{month_name} (#{issue_count} issues)"

            team_data = monthly_reports[month][team_id]

            # Skip if no projects or engineers
            if team_data[:projects].empty?
              puts "  No projects for this team in #{month_name}"
              next
            end

            # Display projects for this team
            team_data[:projects].each do |project_id, project|
              puts "\n  #{'Project:'.bold} #{project[:name]} (#{project[:total_points]} points)"

              if project[:engineers].empty?
                puts "    No engineer contributions to this project in #{month_name}"
                next
              end

              # Create a table for engineers on this project
              rows = []
              project[:engineers].each do |engineer_id, engineer|
                # Find this engineer's total points across all projects
                engineer_total = team_data[:engineers][engineer_id][:total_points]
                percentage = ((engineer[:points].to_f / engineer_total) * 100).round(2)

                rows << [
                  engineer[:name],
                  engineer[:points],
                  "#{engineer_total} points",
                  "#{percentage}%"
                ]
              end

              # Sort rows by percentage (highest first)
              rows = rows.sort_by { |row| -row[1] }

              # Create table headers
              headers = ['Engineer', 'Project Points', 'Total Points', 'Percentage']

              # Use the centralized table renderer
              puts LinearCli::UI::TableRenderer.render_table(
                headers,
                rows,
                widths: {
                  'Engineer' => 20,
                  'Project Points' => 15,
                  'Total Points' => 15,
                  'Percentage' => 15
                }
              )
            end
          end
        end
      end

      # Display a summary view of the workload report
      def display_summary_workload_report(monthly_reports, teams)
        puts "\n#{'Monthly Engineer Workload Summary (Past 6 Months)'.bold}"

        # Sort months chronologically (oldest to newest)
        sorted_months = monthly_reports.keys.sort

        # Create a table showing engineers and their monthly point totals
        teams.each do |team|
          team_id = team['id']
          team_name = team['name']

          # Check if team has data in any month
          has_team_data = sorted_months.any? do |month|
            monthly_reports[month][team_id] &&
              !monthly_reports[month][team_id][:engineers].empty?
          end

          next unless has_team_data

          puts "\n#{'=' * 80}"
          puts "Team: #{team_name.bold}"
          puts "#{'=' * 80}"

          # Collect all engineers who have contributed to this team
          all_engineers = {}
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
        end
      end

      # Display workload report for a single period
      def display_single_period_workload_report(workload_data, teams, period)
        period_desc = period == 'all' ? 'All Time' : "Current #{period.capitalize}"
        puts "\n#{'Engineer Workload Report ('.bold}#{period_desc.bold})"

        # For each team
        teams.each do |team|
          team_id = team['id']
          team_name = team['name']

          # Skip if team has no data
          next unless workload_data[team_id] && !workload_data[team_id][:projects].empty?

          puts "\n#{'=' * 80}"
          puts "Team: #{team_name.bold}"
          puts "#{'=' * 80}"

          team_data = workload_data[team_id]

          # Display projects for this team
          team_data[:projects].each do |project_id, project|
            puts "\n  #{'Project:'.bold} #{project[:name]} (#{project[:total_points]} points)"

            if project[:engineers].empty?
              puts '    No engineer contributions to this project'
              next
            end

            # Create a table for engineers on this project
            rows = []
            project[:engineers].each do |engineer_id, engineer|
              # Find this engineer's total points across all projects
              engineer_total = team_data[:engineers][engineer_id][:total_points]
              percentage = ((engineer[:points].to_f / engineer_total) * 100).round(2)

              rows << [
                engineer[:name],
                engineer[:points],
                "#{engineer_total} points",
                "#{percentage}%"
              ]
            end

            # Sort rows by points (highest first)
            rows = rows.sort_by { |row| -row[1] }

            # Create table headers
            headers = ['Engineer', 'Project Points', 'Total Points', 'Percentage']

            # Use the centralized table renderer
            puts LinearCli::UI::TableRenderer.render_table(
              headers,
              rows,
              widths: {
                'Engineer' => 20,
                'Project Points' => 15,
                'Total Points' => 15,
                'Percentage' => 15
              }
            )
          end
        end
      end

      # Display summary workload report for a single period
      def display_single_period_summary_report(workload_data, teams, period)
        period_desc = period == 'all' ? 'All Time' : "Current #{period.capitalize}"
        puts "\n#{'Engineer Workload Summary ('.bold}#{period_desc.bold})"

        # For each team
        teams.each do |team|
          team_id = team['id']
          team_name = team['name']

          # Skip if team has no data
          next unless workload_data[team_id] && !workload_data[team_id][:engineers].empty?

          puts "\n#{'=' * 80}"
          puts "Team: #{team_name.bold}"
          puts "#{'=' * 80}"

          team_data = workload_data[team_id]

          # Create a table showing engineers and their project distributions
          headers = ['Engineer', 'Total Points']

          # Add all project names to headers
          project_columns = {}
          team_data[:projects].keys.each_with_index do |project_id, index|
            project_name = team_data[:projects][project_id][:name]
            headers << project_name
            project_columns[project_id] = index + 2 # +2 for engineer and total columns
          end

          # Create rows with engineer point totals and percentages by project
          rows = []
          team_data[:engineers].each do |engineer_id, engineer|
            row = [engineer[:name], engineer[:total_points]]

            # Fill with zeroes first
            project_columns.size.times { row << '0%' }

            # Fill in actual percentages
            engineer[:projects].each do |project_id, project|
              row[project_columns[project_id]] = "#{project[:percentage]}%" if project_columns[project_id]
            end

            rows << row
          end

          # Sort rows by total points (highest first)
          rows = rows.sort_by { |row| -row[1] }

          # Use the centralized table renderer
          puts LinearCli::UI::TableRenderer.render_table(headers, rows)
        end
      end
    end
  end
end
