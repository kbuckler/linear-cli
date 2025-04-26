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
        - Overall capitalization metrics across the workspace
        - Team-level breakdown of capitalization rates
        - Counts of capitalized vs. non-capitalized issues

        Examples:
          linear analytics capitalization                # Output in table format
          linear analytics capitalization --format=json  # Output in JSON format
      LONGDESC
      option :format,
             type: :string,
             desc: 'Output format (json or table)',
             default: 'table',
             required: false
      def capitalization
        format = options[:format]&.downcase || 'table'
        validate_format(format)

        client = LinearCli::API::Client.new

        # Get projects and issues for capitalization analysis
        projects_data = fetch_projects(client)
        issues_data = fetch_issues(client)

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
    end
  end
end
