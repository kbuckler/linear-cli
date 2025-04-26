require 'thor'
require 'pastel'
require 'tty-table'

module LinearCli
  module Commands
    # Command group for managing Linear teams
    class Teams < Thor
      package_name 'linear teams'

      desc 'list', 'List Linear teams'
      def list
        client = LinearCli::API::Client.new

        # Execute the query
        result = client.query(LinearCli::API::Queries::Teams.list_teams)
        teams = result['teams']['nodes']

        if teams.empty?
          puts 'No teams found.'
          return
        end

        # Create a table for display
        table = TTY::Table.new(
          header: %w[Key Name Members States],
          rows: teams.map do |team|
            members_count = team['members']['nodes'].size
            states_count = team['states']['nodes'].size

            [
              team['key'],
              team['name'],
              members_count,
              states_count
            ]
          end
        )

        pastel = Pastel.new
        puts pastel.bold("Linear Teams (#{teams.size}):")
        puts table.render(:unicode, padding: [0, 1, 0, 1], resize: false)
      end

      desc 'view ID', 'View details of a specific team'
      def view(id)
        client = LinearCli::API::Client.new

        # Execute the query
        result = client.query(LinearCli::API::Queries::Teams.get_team, { id: id })
        team = result['team']

        if team.nil?
          puts "Team not found: #{id}"
          return
        end

        pastel = Pastel.new
        puts pastel.bold("#{team['key']}: #{team['name']}")
        puts "Description: #{team['description'] || 'No description provided.'}"

        # Display members
        puts "\nMembers:"
        if team['members'] && !team['members']['nodes'].empty?
          team['members']['nodes'].each do |member|
            user = member['user']
            puts "- #{user['name']} (#{user['email']})"
          end
        else
          puts 'No members.'
        end

        # Display states
        puts "\nStates:"
        if team['states'] && !team['states']['nodes'].empty?
          states_table = TTY::Table.new(
            header: %w[Name Color Position],
            rows: team['states']['nodes'].map do |state|
              [
                state['name'],
                state['color'],
                state['position']
              ]
            end
          )
          puts states_table.render(:unicode, padding: [0, 1, 0, 1], resize: false)
        else
          puts 'No states.'
        end

        # Display labels
        puts "\nLabels:"
        if team['labels'] && !team['labels']['nodes'].empty?
          labels_table = TTY::Table.new(
            header: %w[Name Color],
            rows: team['labels']['nodes'].map do |label|
              [
                label['name'],
                label['color']
              ]
            end
          )
          puts labels_table.render(:unicode, padding: [0, 1, 0, 1], resize: false)
        else
          puts 'No labels.'
        end

        # Display cycles
        puts "\nCycles:"
        if team['cycles'] && !team['cycles']['nodes'].empty?
          cycles_table = TTY::Table.new(
            header: ['Name', 'Start Date', 'End Date'],
            rows: team['cycles']['nodes'].map do |cycle|
              [
                cycle['name'],
                cycle['startsAt'],
                cycle['endsAt']
              ]
            end
          )
          puts cycles_table.render(:unicode, padding: [0, 1, 0, 1], resize: false)
        else
          puts 'No cycles.'
        end
      end
    end
  end
end
