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

      desc 'team_workload TEAM_NAME', 'Show workload analysis for a specific team'
      option :period, type: :string, default: 'all',
                      desc: 'Time period (month, quarter, year, all)',
                      enum: %w[month quarter year all]
      option :detailed, type: :boolean, default: false,
                        desc: 'Show detailed data per team member'
      option :format, type: :string, default: 'table',
                      desc: 'Output format (table or json)',
                      enum: %w[table json]
      def team_workload(team_name)
        # Validate format if provided
        format = options[:format]&.downcase || 'table'
        validate_format(format)

        client = LinearCli::API::Client.new
        data_fetcher = LinearCli::Services::Analytics::DataFetcher.new(client)
        period_filter = LinearCli::Services::Analytics::PeriodFilter.new
        workload_calculator = LinearCli::Services::Analytics::WorkloadCalculator.new

        # Log the start of workload analysis with context
        LinearCli::UI::Logger.info("Fetching workload data for team '#{team_name}'...",
                                   { team: team_name, period: options[:period], detailed: options[:detailed] })

        begin
          # Fetch team data
          team_data = data_fetcher.fetch_team_data(team_name)
          team_id = team_data['id']

          # Fetch team workload data (projects and issues)
          team_workload = data_fetcher.fetch_team_workload_data(team_id)

          # Extract issues and add information about the count
          issues = team_workload['issues']['nodes'] || []
          LinearCli::UI::Logger.info("Processing #{issues.size} issues...", { count: issues.size })

          # Filter issues by period
          filtered_issues = period_filter.filter_issues_by_period(issues, options[:period])
          LinearCli::UI::Logger.info("Filtered to #{filtered_issues.size} issues for the selected period",
                                     { period: options[:period], filtered_count: filtered_issues.size })

          # Get projects from the team workload data
          projects = team_workload['projects']['nodes'] || []
          LinearCli::UI::Logger.info("Analyzing #{filtered_issues.size} issues across #{projects.size} projects...",
                                     { issue_count: filtered_issues.size, project_count: projects.size })

          # Calculate workload metrics
          monthly_data = workload_calculator.calculate_monthly_workload(filtered_issues)
          project_data = workload_calculator.calculate_project_workload(filtered_issues, projects)

          # Output based on format
          if format == 'json'
            # Display JSON output
            output_data = {
              team: team_name,
              period: options[:period],
              monthly_data: monthly_data,
              project_data: project_data
            }
            puts JSON.pretty_generate(output_data)
          else
            # Display the workload report
            display_team_workload_report(team_name, monthly_data, project_data, options[:detailed])
          end
        rescue StandardError => e
          LinearCli::UI::Logger.error("Failed to analyze workload for team '#{team_name}': #{e.message}",
                                      { team: team_name, error: e.class.name })
          raise
        end
      end

      private

      def validate_format(format)
        return if %w[json table].include?(format)

        raise "Invalid format: #{format}. Must be 'json' or 'table'."
      end

      # Display the workload report
      # @param team_name [String] Team name
      # @param monthly_data [Hash] Monthly workload data
      # @param project_data [Hash] Project workload data
      # @param detailed [Boolean] Whether to show detailed data
      def display_team_workload_report(team_name, monthly_data, project_data, detailed)
        # Log that we're about to display the report
        LinearCli::UI::Logger.debug('Preparing to display team workload report',
                                    { team: team_name, detailed_view: detailed })

        # Display monthly summary
        display_monthly_summary(team_name, monthly_data)

        # Display project details
        display_project_details(project_data, detailed)
      end

      # Display the monthly summary for a team
      # @param team_name [String] Team name
      # @param monthly_data [Hash] Monthly workload data
      def display_monthly_summary(team_name, monthly_data)
        puts "\n#{'Monthly Team Workload Report (Past 6 Months)'.bold}"
        puts "\n#{'=' * 80}"
        puts "Team: #{team_name.bold}"
        puts('=' * 80)

        # Sort months chronologically (oldest to newest)
        sorted_months = monthly_data.keys.sort

        # Check if team has data in any month
        has_data = sorted_months.any? do |month|
          monthly_data[month][:contributors].any?
        end

        unless has_data
          puts '  No data available for this team in the past 6 months.'
          return
        end

        # Create a table showing contributors and their monthly point totals
        all_contributors = {}

        # Collect all contributors who have contributed to this team
        sorted_months.each do |month|
          monthly_data[month][:contributors].each do |contributor_id, contributor|
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
            if monthly_data[month][:contributors][contributor_id]
              points = monthly_data[month][:contributors][contributor_id][:total_points]
              issues = monthly_data[month][:contributors][contributor_id][:issues_count]
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
          headers << monthly_data[month][:month_name]
        end

        # Add a total column
        headers << 'Total (Points / Issues)'
        rows.each do |row|
          # No need to add the total here, as we've already added it above when creating the rows
        end

        # Use the centralized table renderer
        puts LinearCli::UI::TableRenderer.render_table(headers, rows)
      end

      # Display the project details for a team
      # @param project_data [Hash] Project workload data
      # @param detailed [Boolean] Whether to show detailed data
      def display_project_details(project_data, detailed)
        # For each month, show project details
        project_data.each do |month, data|
          month_name = data[:month_name]

          # Skip if no projects for this month
          next if data[:projects].empty?

          puts "\n#{'Month:'.bold} #{month_name} (#{data[:issue_count]} issues)"

          # Display projects for this team in this month
          data[:projects].each_value do |project|
            next if project[:contributors].empty?

            puts "  #{'Project:'.bold} #{project[:name]} (#{project[:total_points]} points, #{project[:issues_count]} issues)"

            # List contributors who worked on this project
            project[:contributors].each_value do |contributor|
              points_per_issue = contributor[:issues_count].positive? ? (contributor[:points].to_f / contributor[:issues_count]).round(1) : 0
              issue_percentage = project[:issues_count].positive? ? ((contributor[:issues_count].to_f / project[:issues_count]) * 100).round(1) : 0

              # Find the percentage of this project of the contributor's total work
              # We can simplify this by finding the contributor in the main contributor list
              contributor_id = find_contributor_id_by_name(contributor[:name], data[:contributors])
              project_of_total_percentage = 0

              if contributor_id
                # Get the contributor's total data
                total_contributor = data[:contributors][contributor_id]
                # Find this project in the contributor's projects
                project_data = total_contributor[:projects][project_id_from_name(project[:name], data[:projects])]
                if project_data
                  project_of_total_percentage = project_data[:percentage].round(1)
                end
              end

              puts "    - #{contributor[:name]}: #{contributor[:points]} points (#{contributor[:percentage].round(1)}% of project), " \
                   "#{contributor[:issues_count]} issues (#{issue_percentage}%), " \
                   "#{points_per_issue} points/issue, " \
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
