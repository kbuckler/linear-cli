require 'thor'
require 'tty-table'
require 'json'
require_relative '../api/client'
require_relative '../api/queries/generator'
require_relative '../analytics/reporting'
require_relative '../analytics/display'

module LinearCli
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
        - Software capitalization metrics (determined by project labels)

        You can output the report in table format (human-readable) or JSON format (for further processing).

        Examples:
          linear analytics report                # Output in table format
          linear analytics report --format=json  # Output in JSON format
          linear analytics capitalization        # Generate capitalization metrics
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

      desc 'capitalization', 'Generate a report focused on software capitalization metrics'
      long_desc <<-LONGDESC
        Generates a report specifically focused on software capitalization metrics.

        This command analyzes your Linear workspace data to identify capitalized work
        based on project labels. Capitalization status is determined by the presence of#{' '}
        labels like 'capitalization', 'capex', or 'fixed asset' on projects.

        The report includes:
        - List of capitalized projects
        - Overall capitalization metrics across the workspace
        - Team-level breakdown of capitalization rates
        - Engineer workload allocation to capitalized projects
        - Counts of capitalized vs. non-capitalized issues
        - Time and effort estimates for capitalized work

        You can filter the data by time period using the --period option.

        Examples:
          linear analytics capitalization                      # Output in table format
          linear analytics capitalization --format=json        # Output in JSON format
          linear analytics capitalization --period=month       # Only analyze current month's data
          linear analytics capitalization --period=quarter     # Only analyze current quarter's data
      LONGDESC
      option :format,
             type: :string,
             desc: 'Output format (json or table)',
             default: 'table',
             required: false
      option :period,
             type: :string,
             desc: 'Time period to analyze (month, quarter, year)',
             default: 'all',
             required: false
      def capitalization
        format = options[:format]&.downcase || 'table'
        period = options[:period]&.downcase || 'all'

        validate_format(format)
        validate_period(period)

        client = LinearCli::API::Client.new

        # Get projects and issues for capitalization analysis
        projects_data = fetch_projects(client)
        issues_data = fetch_issues(client)

        # Filter issues by time period if needed
        issues_data = filter_issues_by_period(issues_data, period) unless period == 'all'

        # Calculate capitalization metrics
        cap_metrics = LinearCli::Analytics::Reporting.calculate_capitalization_metrics(
          issues_data,
          projects_data
        )

        # Output based on requested format
        if format == 'json'
          puts JSON.pretty_generate(cap_metrics)
        else
          LinearCli::Analytics::Display.display_capitalization_metrics(cap_metrics)
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
          linear analytics engineer_workload               # Output in table format
          linear analytics engineer_workload --format=json # Output in JSON format
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

        # Get all teams
        puts 'Fetching teams data...'
        teams_data = fetch_teams(client)

        # Get all projects
        puts 'Fetching projects data...'
        projects_data = fetch_projects(client)

        # Get all issues for the past 6 months
        puts 'Fetching issues data for the past 6 months...'
        all_issues_data = fetch_issues(client)

        # Calculate the date 6 months ago
        six_months_ago = (Time.now - (6 * 30 * 24 * 60 * 60)).strftime('%Y-%m-%d')
        issues_data = all_issues_data.select do |issue|
          issue['createdAt'] && issue['createdAt'] >= six_months_ago
        end

        puts "Analyzing #{issues_data.size} issues from the past 6 months..."

        # Group issues by month
        monthly_issues = {}
        (0..5).each do |months_ago|
          month_date = (Time.now - (months_ago * 30 * 24 * 60 * 60))
          month_key = month_date.strftime('%Y-%m')
          month_name = month_date.strftime('%B %Y')

          # Filter issues for this month
          monthly_issues[month_key] = {
            name: month_name,
            issues: issues_data.select do |issue|
              created_at = Time.parse(issue['createdAt'])
              created_at.strftime('%Y-%m') == month_key
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
        end

        # Output based on requested format
        if format == 'json'
          puts JSON.pretty_generate(monthly_reports)
        else
          display_engineer_workload_report(monthly_reports, teams_data)
        end
      end

      private

      def fetch_teams(client)
        puts 'Fetching teams data...'

        query = LinearCli::API::Queries::Generator.list_teams_for_generator
        result = client.query(query)
        result.dig('teams', 'nodes') || []
      end

      def fetch_projects(client)
        puts 'Fetching projects data...'

        query = LinearCli::API::Queries::Generator.list_projects_for_reporting
        result = client.query(query)
        result.dig('projects', 'nodes') || []
      end

      def fetch_issues(client)
        puts 'Fetching issues data...'

        query = LinearCli::API::Queries::Generator.list_issues_for_reporting
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

      def filter_issues_by_period(issues, period)
        current_time = Time.now

        issues.select do |issue|
          # Skip issues without creation date
          next false unless issue['createdAt']

          created_at = Time.parse(issue['createdAt'])

          case period
          when 'month'
            same_month_and_year?(created_at, current_time)
          when 'quarter'
            same_quarter_and_year?(created_at, current_time)
          when 'year'
            same_year?(created_at, current_time)
          else
            true
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

      # Display the engineer workload report
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

            # Skip if team has no data this month
            next unless monthly_reports[month][team_id]

            puts "\n#{'Month:'.bold} #{month_name}"

            team_data = monthly_reports[month][team_id]

            # Skip if no projects or engineers
            if team_data[:projects].empty?
              puts "  No projects for this team in #{month_name}"
              next
            end

            # Display projects for this team
            team_data[:projects].each do |project_id, project|
              puts "\n  #{'Project:'.bold} #{project[:name]}"

              if project[:engineers].empty?
                puts "    No engineer contributions to this project in #{month_name}"
                next
              end

              # Create a table for engineers on this project
              rows = []
              project[:engineers].each do |_engineer_id, engineer|
                # Find this engineer's total points across all projects
                engineer_total = team_data[:engineers][_engineer_id][:total_points]
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

              # Create and display the table
              table = TTY::Table.new(
                ['Engineer', 'Project Points', 'Total Points', 'Percentage'],
                rows
              )

              puts table.render(:unicode, padding: [0, 1])
            end
          end
        end
      end
    end
  end
end
