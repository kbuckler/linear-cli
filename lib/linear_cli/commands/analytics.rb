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
    end
  end
end
