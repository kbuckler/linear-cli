require 'thor'
require 'pastel'
require_relative '../ui/table_renderer'

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

        # Prepare data for table rendering
        headers = %w[Key Name Members States]
        rows = teams.map do |team|
          members_count = team['members']['nodes'].size
          states_count = team['states']['nodes'].size

          [
            team['key'],
            team['name'],
            members_count,
            states_count
          ]
        end

        # Use the centralized table renderer
        LinearCli::UI::TableRenderer.output_table(
          "Linear Teams (#{teams.size}):",
          headers,
          rows,
          widths: { 'Key' => 8, 'Name' => 25, 'Members' => 10, 'States' => 10 }
        )
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
          headers = %w[Name Color Position]
          rows = team['states']['nodes'].map do |state|
            [
              state['name'],
              state['color'],
              state['position']
            ]
          end

          puts LinearCli::UI::TableRenderer.render_table(
            headers,
            rows,
            widths: { 'Name' => 20, 'Color' => 15, 'Position' => 10 }
          )
        else
          puts 'No states.'
        end

        # Display labels
        puts "\nLabels:"
        if team['labels'] && !team['labels']['nodes'].empty?
          headers = %w[Name Color]
          rows = team['labels']['nodes'].map do |label|
            [
              label['name'],
              label['color']
            ]
          end

          puts LinearCli::UI::TableRenderer.render_table(
            headers,
            rows,
            widths: { 'Name' => 25, 'Color' => 15 }
          )
        else
          puts 'No labels.'
        end

        # Display cycles
        puts "\nCycles:"
        if team['cycles'] && !team['cycles']['nodes'].empty?
          headers = ['Name', 'Start Date', 'End Date']
          rows = team['cycles']['nodes'].map do |cycle|
            [
              cycle['name'],
              cycle['startsAt'],
              cycle['endsAt']
            ]
          end

          puts LinearCli::UI::TableRenderer.render_table(
            headers,
            rows,
            widths: { 'Name' => 25, 'Start Date' => 15, 'End Date' => 15 }
          )
        else
          puts 'No cycles.'
        end
      end
    end
  end
end
