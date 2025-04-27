require 'thor'
require 'pastel'
require 'tty-table'

module LinearCli
  module Commands
    # Command group for managing Linear projects
    class Projects < Thor
      package_name 'linear projects'

      desc 'list', 'List Linear projects'
      def list
        client = LinearCli::API::Client.new

        # Execute the query
        result = client.query(LinearCli::API::Queries::Projects.list_projects)
        projects = result['projects']['nodes']

        if projects.empty?
          puts 'No projects found.'
          return
        end

        # Create a table for display
        table = TTY::Table.new(
          header: %w[Name State Progress Teams Lead],
          rows: projects.map do |project|
            lead_name = project['lead'] ? project['lead']['name'] : 'None'
            teams = project['teams']['nodes'].map { |t| t['name'] }.join(', ')

            [
              project['name'],
              project['state'],
              "#{project['progress'] || 0}%",
              teams,
              lead_name
            ]
          end
        )

        pastel = Pastel.new
        puts pastel.bold("Linear Projects (#{projects.size}):")
        puts table.render(:unicode, padding: [0, 1, 0, 1], resize: false) do |renderer|
          renderer.width = [30, 15, 10, 25, 20]
        end
      end

      desc 'view ID', 'View details of a specific project'
      def view(id)
        client = LinearCli::API::Client.new

        # Execute the query
        result = client.query(LinearCli::API::Queries::Projects.get_project, { id: id })
        project = result['project']

        if project.nil?
          puts "Project not found: #{id}"
          return
        end

        pastel = Pastel.new
        puts pastel.bold(project['name'])
        puts "State: #{project['state']}"
        puts "Progress: #{project['progress'] || 0}%"
        puts "Lead: #{project['lead'] ? project['lead']['name'] : 'None'}"
        puts "Start Date: #{project['startDate'] || 'Not set'}"
        puts "Target Date: #{project['targetDate'] || 'Not set'}"
        puts "\nDescription:"
        puts project['description'] || 'No description provided.'

        # Display teams
        puts "\nTeams:"
        if project['teams'] && !project['teams']['nodes'].empty?
          project['teams']['nodes'].each do |team|
            puts "- #{team['name']}"
          end
        else
          puts 'No teams.'
        end

        # Display members
        puts "\nMembers:"
        if project['members'] && !project['members']['nodes'].empty?
          project['members']['nodes'].each do |member|
            puts "- #{member['name']}"
          end
        else
          puts 'No members.'
        end

        # Display issues
        puts "\nIssues:"
        if project['issues'] && !project['issues']['nodes'].empty?
          issues_table = TTY::Table.new(
            header: %w[ID Title Status],
            rows: project['issues']['nodes'].map do |issue|
              [
                issue['identifier'],
                issue['title'],
                issue['state']['name']
              ]
            end
          )
          puts issues_table.render(:unicode, padding: [0, 1, 0, 1], resize: false) do |renderer|
            renderer.width = [10, 40, 15]
          end
        else
          puts 'No issues.'
        end
      end
    end
  end
end
