require 'thor'
require 'tty-table'
require 'json'

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
        display_projects(results[:projects]) if results[:projects].any?

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
        report_data = {
          teams: teams_data,
          projects: projects_data,
          issues: issues_data,
          summary: {
            teams_count: teams_data.size,
            projects_count: projects_data.size,
            issues_count: issues_data.size,
            issues_by_status: count_issues_by_status(issues_data),
            issues_by_team: count_issues_by_team(issues_data),
            team_completion_rates: calculate_team_completion_rates(issues_data)
          }
        }

        # Output based on requested format
        if format == 'json'
          puts JSON.pretty_generate(report_data)
        else
          display_summary_tables(report_data[:summary])
        end
      end

      private

      def fetch_existing_teams(client)
        puts 'Fetching existing teams from Linear...'

        query = <<~GRAPHQL
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

      def validate_format(format)
        return if %w[json table].include?(format)

        raise "Invalid format: #{format}. Must be 'json' or 'table'."
      end

      def display_teams(teams)
        return if teams.empty?

        puts "\nTeams:"
        table = TTY::Table.new(
          %w[Name Key ID],
          teams.map { |t| [t['name'], t['key'], t['id']] }
        )

        # Use simple output in test environments
        if in_test_environment?
          puts 'Name | Key | ID'
          puts '-----+-----+----'
          teams.each do |team|
            puts "#{team['name']} | #{team['key']} | #{team['id']}"
          end
        else
          puts table.render(:unicode, padding: [0, 1])
        end
      end

      def display_projects(projects)
        return if projects.empty?

        puts "\nProjects:"
        table = TTY::Table.new(
          %w[Name State ID],
          projects.map { |p| [p['name'], p['state'], p['id']] }
        )

        # Use simple output in test environments
        if in_test_environment?
          puts 'Name | State | ID'
          puts '-----+-------+----'
          projects.each do |project|
            puts "#{project['name']} | #{project['state']} | #{project['id']}"
          end
        else
          puts table.render(:unicode, padding: [0, 1])
        end
      end

      def fetch_teams(client)
        puts 'Fetching teams data...'

        query = <<~GRAPHQL
          query Teams {
            teams {
              nodes {
                id
                name
                key
                description
                states {
                  nodes {
                    id
                    name
                    type
                  }
                }
              }
            }
          }
        GRAPHQL

        result = client.query(query)
        result.dig('teams', 'nodes') || []
      end

      def fetch_projects(client)
        puts 'Fetching projects data...'

        query = <<~GRAPHQL
          query Projects {
            projects {
              nodes {
                id
                name
                description
                state
                progress
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

        result = client.query(query)
        result.dig('projects', 'nodes') || []
      end

      def fetch_issues(client)
        puts 'Fetching issues data...'

        query = <<~GRAPHQL
          query Issues($first: Int) {
            issues(first: $first) {
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
                createdAt
                updatedAt
                completedAt
              }
            }
          }
        GRAPHQL

        result = client.query(query, { first: 100 })
        result.dig('issues', 'nodes') || []
      end

      def count_issues_by_status(issues)
        issues.each_with_object(Hash.new(0)) do |issue, counts|
          status = issue.dig('state', 'name') || 'Unknown'
          counts[status] += 1
        end
      end

      def count_issues_by_team(issues)
        issues.each_with_object(Hash.new(0)) do |issue, counts|
          team = issue.dig('team', 'name') || 'Unknown'
          counts[team] += 1
        end
      end

      def calculate_team_completion_rates(issues)
        team_issues = issues.group_by { |i| i.dig('team', 'name') || 'Unknown' }

        team_issues.transform_values do |team_issues_list|
          total = team_issues_list.size
          completed = team_issues_list.count { |i| i['completedAt'] }
          {
            total: total,
            completed: completed,
            rate: total > 0 ? (completed.to_f / total * 100).round(2) : 0
          }
        end
      end

      def display_summary_tables(summary)
        puts "\nSummary:"
        puts "Teams: #{summary[:teams_count]}"
        puts "Projects: #{summary[:projects_count]}"
        puts "Issues: #{summary[:issues_count]}"

        # Issues by status
        if summary[:issues_by_status].any?
          puts "\nIssues by Status:"

          if in_test_environment?
            puts 'Status | Count'
            puts '-------+------'
            summary[:issues_by_status].each do |status, count|
              puts "#{status} | #{count}"
            end
          else
            table = TTY::Table.new(
              %w[Status Count],
              summary[:issues_by_status].map { |status, count| [status, count] }
            )
            puts table.render(:unicode, padding: [0, 1])
          end
        end

        # Issues by team
        if summary[:issues_by_team].any?
          puts "\nIssues by Team:"

          if in_test_environment?
            puts 'Team | Count'
            puts '------+------'
            summary[:issues_by_team].each do |team, count|
              puts "#{team} | #{count}"
            end
          else
            table = TTY::Table.new(
              %w[Team Count],
              summary[:issues_by_team].map { |team, count| [team, count] }
            )
            puts table.render(:unicode, padding: [0, 1])
          end
        end

        # Team completion rates
        return unless summary[:team_completion_rates].any?

        puts "\nTeam Completion Rates:"

        if in_test_environment?
          puts 'Team | Completed | Total | Rate (%)'
          puts '------+-----------+-------+--------'
          summary[:team_completion_rates].each do |team, data|
            puts "#{team} | #{data[:completed]} | #{data[:total]} | #{data[:rate]}"
          end
        else
          table = TTY::Table.new(
            ['Team', 'Completed', 'Total', 'Rate (%)'],
            summary[:team_completion_rates].map do |team, data|
              [team, data[:completed], data[:total], data[:rate]]
            end
          )
          puts table.render(:unicode, padding: [0, 1])
        end
      end

      def in_test_environment?
        defined?(RSpec) || ENV['RACK_ENV'] == 'test' || ENV['RAILS_ENV'] == 'test' || !$stdout.tty?
      end
    end
  end
end
