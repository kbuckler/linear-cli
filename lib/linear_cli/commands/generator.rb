require 'thor'
require 'tty-table'
require 'json'
require_relative '../api/data_generator'
require_relative '../api/queries/generator'
require_relative '../analytics/display'

module LinearCli
  module Commands
    # Commands related to generating data for Linear
    class Generator < Thor
      desc 'populate', 'Populate Linear with generated test data'
      long_desc <<-LONGDESC
        Populates your Linear workspace with test data for development and testing purposes.

        This command creates projects and issues for existing teams in your Linear workspace.
        You can control the amount of data generated with options to specify the number of teams,
        projects per team, and issues per project.

        Example:
          linear generator populate --teams=3 --projects_per_team=2 --issues_per_project=10
      LONGDESC
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

      desc 'dump', 'Dump detailed reporting data from Linear (DEPRECATED)'
      long_desc <<-LONGDESC
        DEPRECATED: This command has been removed.#{' '}

        Please use 'linear analytics report' for comprehensive reporting.

        This command will be removed in a future version.
      LONGDESC
      option :format,
             type: :string,
             desc: 'Output format (json or table)',
             default: 'table',
             required: false
      def dump
        puts 'DEPRECATED: The dump command has been removed.'
        puts 'Please use the following command instead:'
        puts '  linear analytics report         # For comprehensive reports'
        puts '  linear analytics capitalization # For capitalization metrics only'
        puts "\nThis command will be removed in a future version."
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
    end
  end
end
