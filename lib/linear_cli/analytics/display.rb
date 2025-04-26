module LinearCli
  module Analytics
    # Display formatting for analytics data
    module Display
      # Check if running in test environment
      # @return [Boolean] True if running in test environment
      def self.in_test_environment?
        defined?(RSpec) || ENV['RACK_ENV'] == 'test' || ENV['RAILS_ENV'] == 'test' || !$stdout.tty?
      end

      # Display teams table
      # @param teams [Array<Hash>] Team data
      # @return [void]
      def self.display_teams(teams)
        return if teams.empty?

        puts "\nTeams:"
        if in_test_environment?
          puts 'Name | Key | ID'
          puts '-----+-----+----'
          teams.each do |team|
            puts "#{team['name']} | #{team['key']} | #{team['id']}"
          end
        else
          table = TTY::Table.new(
            %w[Name Key ID],
            teams.map { |t| [t['name'], t['key'], t['id']] }
          )
          puts table.render(:unicode, padding: [0, 1])
        end
      end

      # Display projects table
      # @param projects [Array<Hash>] Project data
      # @return [void]
      def self.display_projects(projects)
        return if projects.empty?

        puts "\nProjects:"
        if in_test_environment?
          puts 'Name | State | ID'
          puts '-----+-------+----'
          projects.each do |project|
            puts "#{project['name']} | #{project['state']} | #{project['id']}"
          end
        else
          table = TTY::Table.new(
            %w[Name State ID],
            projects.map { |p| [p['name'], p['state'], p['id']] }
          )
          puts table.render(:unicode, padding: [0, 1])
        end
      end

      # Display summary tables for report data
      # @param summary [Hash] Summary data
      # @return [void]
      def self.display_summary_tables(summary)
        puts "\nSummary:"
        puts "Teams: #{summary[:teams_count]}"
        puts "Projects: #{summary[:projects_count]}"
        puts "Issues: #{summary[:issues_count]}"

        # Issues by status
        display_status_table(summary[:issues_by_status]) if summary[:issues_by_status].any?

        # Issues by team
        display_team_table(summary[:issues_by_team]) if summary[:issues_by_team].any?

        # Team completion rates
        display_completion_table(summary[:team_completion_rates]) if summary[:team_completion_rates].any?

        # Capitalization metrics
        display_capitalization_metrics(summary[:capitalization_metrics]) if summary[:capitalization_metrics]
      end

      # Display status distribution table
      # @param status_data [Hash] Status counts
      # @return [void]
      def self.display_status_table(status_data)
        puts "\nIssues by Status:"
        if in_test_environment?
          puts 'Status | Count'
          puts '-------+------'
          status_data.each do |status, count|
            puts "#{status} | #{count}"
          end
        else
          table = TTY::Table.new(
            %w[Status Count],
            status_data.map { |status, count| [status, count] }
          )
          puts table.render(:unicode, padding: [0, 1])
        end
      end

      # Display team distribution table
      # @param team_data [Hash] Team counts
      # @return [void]
      def self.display_team_table(team_data)
        puts "\nIssues by Team:"
        if in_test_environment?
          puts 'Team | Count'
          puts '------+------'
          team_data.each do |team, count|
            puts "#{team} | #{count}"
          end
        else
          table = TTY::Table.new(
            %w[Team Count],
            team_data.map { |team, count| [team, count] }
          )
          puts table.render(:unicode, padding: [0, 1])
        end
      end

      # Display completion rates table
      # @param completion_data [Hash] Completion rate data
      # @return [void]
      def self.display_completion_table(completion_data)
        puts "\nTeam Completion Rates:"
        if in_test_environment?
          puts 'Team | Completed | Total | Rate (%)'
          puts '------+-----------+-------+--------'
          completion_data.each do |team, data|
            puts "#{team} | #{data[:completed]} | #{data[:total]} | #{data[:rate]}"
          end
        else
          table = TTY::Table.new(
            ['Team', 'Completed', 'Total', 'Rate (%)'],
            completion_data.map do |team, data|
              [team, data[:completed], data[:total], data[:rate]]
            end
          )
          puts table.render(:unicode, padding: [0, 1])
        end
      end

      # Display capitalization metrics
      # @param capitalization_data [Hash] Capitalization metrics data
      # @return [void]
      def self.display_capitalization_metrics(capitalization_data)
        return unless capitalization_data

        puts "\nSoftware Capitalization Metrics:"
        puts "Capitalized Issues: #{capitalization_data[:capitalized_count]}"
        puts "Non-Capitalized Issues: #{capitalization_data[:non_capitalized_count]}"
        puts "Total Issues: #{capitalization_data[:total_issues]}"
        puts "Overall Capitalization Rate: #{capitalization_data[:capitalization_rate]}%"

        return unless capitalization_data[:team_capitalization].any?

        display_team_capitalization_table(capitalization_data[:team_capitalization])
      end

      # Display team capitalization table
      # @param team_capitalization [Hash] Team capitalization data
      # @return [void]
      def self.display_team_capitalization_table(team_capitalization)
        puts "\nTeam Capitalization Breakdown:"
        if in_test_environment?
          puts 'Team | Capitalized | Non-Capitalized | Total | Rate (%)'
          puts '------+-------------+----------------+-------+--------'
          team_capitalization.each do |team, data|
            puts "#{team} | #{data[:capitalized]} | #{data[:non_capitalized]} | #{data[:total]} | #{data[:capitalization_rate]}"
          end
        else
          table = TTY::Table.new(
            ['Team', 'Capitalized', 'Non-Capitalized', 'Total', 'Rate (%)'],
            team_capitalization.map do |team, data|
              [team, data[:capitalized], data[:non_capitalized], data[:total], data[:capitalization_rate]]
            end
          )
          puts table.render(:unicode, padding: [0, 1])
        end
      end
    end
  end
end
