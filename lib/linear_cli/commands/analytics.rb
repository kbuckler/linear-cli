# frozen_string_literal: true

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
require_relative '../services/analytics/monthly_processor'
require_relative '../api/queries/analytics'

module LinearCli
  module Commands
    # Commands related to analytics and reporting for Linear data
    class Analytics < Thor
      desc 'report',
           'Generate a comprehensive report from Linear workspace data'
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

      desc 'team_workload',
           'Generate a monthly report of team workload by project and contributor'
      long_desc <<-LONGDESC
        Generates a detailed report of workload for a specific team across projects.

        This command analyzes your Linear workspace data to show how contributors have worked
        on projects over time. For the specified team, the report shows:
        - Each contributor who has worked on team projects
        - The percentage of their total work (measured in story points) spent on each project
        - Monthly breakdown of contributions going back 6 months

        The report provides insights into:
        - How contributors are distributing their time across projects
        - Which projects are receiving the most effort
        - How team priorities have shifted over time
        - Resource allocation within the team

        Examples:
          linear analytics team_workload --team "Engineering"       # Generate workload report for Engineering team
          linear analytics team_workload --team "Design" --format=json  # Output in JSON format
      LONGDESC
      option :format,
             type: :string,
             desc: 'Output format (json or table)',
             default: 'table',
             required: false
      option :team,
             type: :string,
             desc: 'Team name to analyze',
             required: true
      def team_workload
        format = options[:format]&.downcase || 'table'
        team_name = options[:team]
        validate_format(format)

        client = LinearCli::API::Client.new
        data_fetcher = LinearCli::Services::Analytics::DataFetcher.new(client)

        # Get the specified team
        team = data_fetcher.fetch_team_by_name(team_name)

        unless team
          puts "Error: Team '#{team_name}' not found"
          exit(1)
        end

        puts "Fetching workload data for team '#{team_name}'..."

        # Use the optimized data fetching method that starts with team and pulls projects and issues
        # in a single paginated response
        team_data = data_fetcher.fetch_team_workload_data(team['id'])

        unless team_data && !team_data.empty?
          puts "Error: Could not fetch workload data for team '#{team_name}'"
          exit(1)
        end

        # Extract projects and issues from the nested response
        projects_data = team_data['projects']['nodes'] || []
        issues_data = team_data['issues']['nodes'] || []

        puts "Analyzing #{issues_data.size} issues across #{projects_data.size} projects..."

        period_filter = LinearCli::Services::Analytics::PeriodFilter.new
        monthly_processor = LinearCli::Services::Analytics::MonthlyProcessor.new

        # Filter issues for the last 6 months
        filtered_issues_data = period_filter.filter_issues_by_period(issues_data, 'all')

        # Group issues by month for the past 6 months and calculate workload for the specific team
        monthly_reports = monthly_processor.process_monthly_team_data(
          filtered_issues_data, team_data, projects_data
        )

        # Output based on requested format
        if format == 'json'
          puts JSON.pretty_generate(monthly_reports)
        else
          display_team_workload_report(monthly_reports, team_data)
        end
      end

      private

      def validate_format(format)
        return if %w[json table].include?(format)

        raise "Invalid format: #{format}. Must be 'json' or 'table'."
      end

      # Display the team workload report for monthly data for a specific team
      def display_team_workload_report(monthly_reports, team)
        puts "\n#{'Monthly Team Workload Report (Past 6 Months)'.bold}"
        puts "\n#{'=' * 80}"
        puts "Team: #{team['name'].bold}"
        puts('=' * 80)

        # Sort months chronologically (oldest to newest)
        sorted_months = monthly_reports.keys.sort

        # Check if team has data in any month
        has_data = sorted_months.any? do |month|
          monthly_reports[month][:contributors].any?
        end

        unless has_data
          puts '  No data available for this team in the past 6 months.'
          return
        end

        # Create a table showing contributors and their monthly point totals
        all_contributors = {}

        # Collect all contributors who have contributed to this team
        sorted_months.each do |month|
          monthly_reports[month][:contributors].each do |contributor_id, contributor|
            all_contributors[contributor_id] ||= contributor[:name]
          end
        end

        # Create rows with contributor point totals by month
        rows = []
        all_contributors.each do |contributor_id, contributor_name|
          row = [contributor_name]

          monthly_points = 0
          monthly_issues = 0

          # Add point totals for each month
          sorted_months.each do |month|
            if monthly_reports[month][:contributors][contributor_id]
              points = monthly_reports[month][:contributors][contributor_id][:total_points]
              issues = monthly_reports[month][:contributors][contributor_id][:issues_count]
              monthly_points += points
              monthly_issues += issues
              row << "#{points}p / #{issues}i"
            else
              row << '0p / 0i'
            end
          end

          # Add row only if contributor has points
          rows << row if monthly_points.positive?

          # Add total points and issues
          row << "#{monthly_points}p / #{monthly_issues}i"
        end

        # Sort rows by total points (highest first)
        rows = rows.sort_by do |row|
          # Extract points from the last cell which has format "Xp / Yi"
          last_cell = row.last
          -last_cell.split('p').first.to_i
        end

        # Create headers with month names
        headers = ['Contributor']
        sorted_months.each do |month|
          headers << monthly_reports[month][:month_name]
        end

        # Add a total column
        headers << 'Total (Points / Issues)'
        rows.each do |row|
          # No need to add the total here, as we've already added it above when creating the rows
        end

        # Use the centralized table renderer
        puts LinearCli::UI::TableRenderer.render_table(headers, rows)

        # For each month, show project details
        sorted_months.each do |month|
          month_name = monthly_reports[month][:month_name]

          # Skip if no projects for this month
          next if monthly_reports[month][:projects].empty?

          puts "\n#{'Month:'.bold} #{month_name} (#{monthly_reports[month][:issue_count]} issues)"

          # Display projects for this team in this month
          monthly_reports[month][:projects].each_value do |project|
            next if project[:contributors].empty?

            puts "  #{'Project:'.bold} #{project[:name]} (#{project[:total_points]} points, #{project[:issues_count]} issues)"

            # List contributors who worked on this project
            project[:contributors].each_value do |contributor|
              points_per_issue = contributor[:issues_count] > 0 ? (contributor[:points].to_f / contributor[:issues_count]).round(1) : 0
              issue_percentage = project[:issues_count] > 0 ? ((contributor[:issues_count].to_f / project[:issues_count]) * 100).round(1) : 0

              # Find the percentage of this project of the contributor's total work
              # We can simplify this by finding the contributor in the main contributor list
              contributor_id = find_contributor_id_by_name(contributor[:name], monthly_reports[month][:contributors])
              project_of_total_percentage = 0

              if contributor_id
                # Get the contributor's total data
                total_contributor = monthly_reports[month][:contributors][contributor_id]
                # Find this project in the contributor's projects
                project_data = total_contributor[:projects][project_id_from_name(project[:name], monthly_reports[month][:projects])]
                if project_data
                  project_of_total_percentage = project_data[:percentage].round(1)
                end
              end

              puts "    - #{contributor[:name]}: #{contributor[:points]} points (#{contributor[:percentage].round(1)}% of project), " +
                   "#{contributor[:issues_count]} issues (#{issue_percentage}%), " +
                   "#{points_per_issue} points/issue, " +
                   "#{project_of_total_percentage}% of contributor's work"
            end
          end
        end
      end

      # Helper to find a contributor ID from a name
      def find_contributor_id_by_name(name, contributors)
        contributors.each do |id, contributor|
          return id if contributor[:name] == name
        end
        return 'unassigned' if name == 'Unassigned'

        nil
      end

      # Helper to find a project ID from a name
      def project_id_from_name(name, projects)
        projects.each do |id, project|
          return id if project[:name] == name
        end
        return 'no_project' if name == 'No Project'

        nil
      end
    end
  end
end
