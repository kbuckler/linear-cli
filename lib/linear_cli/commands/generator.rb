require 'thor'
require 'tty-table'
require 'json'
require_relative '../api/data_generator'
require_relative '../api/queries/generator'
require_relative '../analytics/reporting'
require_relative '../analytics/display'

module LinearCli
  module Commands
    # Commands related to generating data for Linear
    class Generator < Thor
      desc 'populate', 'Populate Linear with generated test data'
      option :teams,
             type: :numeric,
             desc: 'Number of teams to create',
             default: 2,
             required: false
      option :projects_per_team,
             type: :numeric,
             desc: 'Number of projects per team',
             default: 2,
             required: false
      option :issues_per_project,
             type: :numeric,
             desc: 'Number of issues per project',
             default: 5,
             required: false
      def populate
        # Validate inputs
        teams_count = sanitize_integer(options[:teams], 1, 5)
        projects_per_team = sanitize_integer(options[:projects_per_team], 1, 5)
        issues_per_project = sanitize_integer(options[:issues_per_project], 1, 10)

        # Initialize client
        client = LinearCli::API::Client.new

        # Try to fetch existing teams first
        existing_teams = fetch_existing_teams(client)

        if existing_teams.empty?
          puts 'No existing teams found. Please create at least one team in Linear first.'
          return
        end

        # Use the data generator
        puts 'Using existing teams from your Linear workspace...'
        generator = LinearCli::API::DataGenerator.new(client)

        results = { teams: [], projects: [], issues: [] }
        teams_to_use = existing_teams.take(teams_count)

        teams_to_use.each do |team|
          results[:teams] << team
          puts "Creating data for team: #{team['name']} (#{team['key']})"

          # Create projects for this team
          projects_per_team.times do |j|
            project = generator.create_project(
              "Test Project #{j + 1}",
              team['id'],
              "Generated test project #{j + 1} for team #{team['name']}"
            )
            results[:projects] << project

            # Create issues for this project
            issues_per_project.times do |k|
              issue = generator.create_issue(
                "Test Issue #{j + 1}-#{k + 1}",
                team['id'],
                {
                  description: "Generated test issue #{k + 1} for project #{j + 1}",
                  project_id: project['id'],
                  priority: rand(5)
                }
              )
              results[:issues] << issue
            end
          rescue StandardError => e
            puts "Warning: Could not create project. #{e.message}"
            # If we can't create projects, try creating issues directly
            if results[:projects].empty?
              puts 'Attempting to create issues directly for the team...'
              issues_per_project.times do |k|
                issue = generator.create_issue(
                  "Test Issue #{k + 1}",
                  team['id'],
                  {
                    description: "Generated test issue #{k + 1}",
                    priority: rand(5)
                  }
                )
                results[:issues] << issue
              rescue StandardError => e
                puts "Error creating issue: #{e.message}"
              end
            end
            break
          end
        end

        # Display results
        puts "\nGeneration complete!"
        puts "Used #{results[:teams].size} teams, created #{results[:projects].size} projects, and #{results[:issues].size} issues."

        # Display projects
        LinearCli::Analytics::Display.display_projects(results[:projects]) if results[:projects].any?

        # Provide hint for querying the generated data
        puts "\nYou can now query the generated data using other Linear CLI commands."
        puts 'For example, you can list all issues with: linear issues list'
      end

      desc 'dump', 'Dump detailed reporting data from Linear'
      option :format,
             type: :string,
             desc: 'Output format (json or table)',
             default: 'table',
             required: false
      def dump
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

      private

      def fetch_existing_teams(client)
        puts 'Fetching existing teams from Linear...'

        query = LinearCli::API::Queries::Generator.list_teams_for_generator
        result = client.query(query)
        teams = result.dig('teams', 'nodes') || []

        puts "Found #{teams.size} teams in your Linear workspace."
        teams
      end

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

      def sanitize_integer(value, min, max)
        value = value.to_i
        if value < min
          min
        elsif value > max
          max
        else
          value
        end
      end

      def validate_format(format)
        return if %w[json table].include?(format)

        raise "Invalid format: #{format}. Must be 'json' or 'table'."
      end
    end
  end
end
