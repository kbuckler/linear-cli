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

      desc 'team_workload', 'Generate a monthly report of team workload by project and contributor'
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

        # Get all projects
        projects_data = data_fetcher.fetch_projects

        # Get all issues
        all_issues_data = data_fetcher.fetch_issues

        period_filter = LinearCli::Services::Analytics::PeriodFilter.new
        monthly_processor = LinearCli::Services::Analytics::MonthlyProcessor.new

        # Filter issues for the last 6 months
        issues_data = period_filter.filter_issues_by_period(all_issues_data, 'all')

        puts "Analyzing #{issues_data.size} issues from the past 6 months..."

        # Group issues by month for the past 6 months and calculate workload for the specific team
        monthly_reports = monthly_processor.process_monthly_team_data(issues_data, team, projects_data)

        # Output based on requested format
        if format == 'json'
          puts JSON.pretty_generate(monthly_reports)
        else
          display_team_workload_report(monthly_reports, team)
        end
      end

      # For backward compatibility - will be deprecated
      desc 'engineer_workload', 'Generate a monthly report of engineer contributions by project and team'
      long_desc <<-LONGDESC
        This command is deprecated and will be removed in a future release.
        Please use 'team_workload' instead for more focused reporting.

        Examples:
          linear analytics team_workload --team "Engineering"  # New command to use
      LONGDESC
      option :format,
             type: :string,
             desc: 'Output format (json or table)',
             default: 'table',
             required: false
      def engineer_workload
        puts "Warning: 'engineer_workload' command is deprecated. Please use 'team_workload' instead."
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
        monthly_processor = LinearCli::Services::Analytics::MonthlyProcessor.new

        # Filter issues for the last 6 months
        issues_data = period_filter.filter_issues_by_period(all_issues_data, 'all')

        puts "Analyzing #{issues_data.size} issues from the past 6 months..."

        # Group issues by month for the past 6 months
        monthly_reports = monthly_processor.process_monthly_data(issues_data, teams_data, projects_data)

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

      # Display the team workload report for monthly data for a specific team
      def display_team_workload_report(monthly_reports, team)
        puts "\n#{'Monthly Team Workload Report (Past 6 Months)'.bold}"
        puts "\n#{'=' * 80}"
        puts "Team: #{team['name'].bold}"
        puts('=' * 80)

        # Sort months chronologically (oldest to newest)
        sorted_months = monthly_reports.keys.sort

        # Check if team has data in any month
        has_data = sorted_months.any? { |month| monthly_reports[month][:contributors].any? }

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

          # Add point totals for each month
          sorted_months.each do |month|
            if monthly_reports[month][:contributors][contributor_id]
              points = monthly_reports[month][:contributors][contributor_id][:total_points]
              row << points
            else
              row << 0
            end
          end

          # Add row only if contributor has points
          rows << row if row[1..].sum.positive?
        end

        # Sort rows by total points (highest first)
        rows = rows.sort_by { |row| -row[1..].sum }

        # Create headers with month names
        headers = ['Contributor']
        sorted_months.each do |month|
          headers << monthly_reports[month][:month_name]
        end

        # Add a total column
        headers << 'Total'
        rows.each do |row|
          row << row[1..].sum
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

            puts "  #{'Project:'.bold} #{project[:name]} (#{project[:total_points]} points)"

            # List contributors who worked on this project
            project[:contributors].each_value do |contributor|
              puts "    - #{contributor[:name]}: #{contributor[:points]} points (#{contributor[:percentage]}%)"
            end
          end
        end
      end

      # Legacy display method for engineer workload report
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
          puts('=' * 80)

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
            rows << row if row[1..].sum.positive?
          end

          # Sort rows by total points (highest first)
          rows = rows.sort_by { |row| -row[1..].sum }

          # Create headers with month names
          headers = ['Engineer']
          sorted_months.each do |month|
            headers << monthly_reports[month][:name]
          end

          # Add a total column
          headers << 'Total'
          rows.each do |row|
            row << row[1..].sum
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
            team_data[:projects].each_value do |project|
              next if project[:engineers].empty?

              puts "  #{'Project:'.bold} #{project[:name]} (#{project[:total_points]} points)"

              # List engineers who worked on this project
              project[:engineers].each_value do |engineer|
                puts "    - #{engineer[:name]}: #{engineer[:points]} points (#{engineer[:percentage]}%)"
              end
            end
          end
        end
      end
    end
  end
end
