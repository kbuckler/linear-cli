require 'terminal-table'
require 'colorize'
require 'tty-spinner'
require_relative '../ui/table_renderer'

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

        headers = %w[Name Key ID]
        rows = teams.map { |t| [t['name'], t['key'], t['id']] }

        LinearCli::UI::TableRenderer.output_table(
          'Teams:',
          headers,
          rows,
          widths: { 'Name' => 25, 'Key' => 8, 'ID' => 10 }
        )
      end

      # Display projects table
      # @param projects [Array<Hash>] Project data
      # @return [void]
      def self.display_projects(projects)
        return if projects.empty?

        headers = %w[Name State ID]
        rows = projects.map { |p| [p['name'], p['state'], p['id']] }

        LinearCli::UI::TableRenderer.output_table(
          'Projects:',
          headers,
          rows,
          widths: { 'Name' => 25, 'State' => 15, 'ID' => 10 }
        )
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
        headers = %w[Status Count]
        rows = status_data.map { |status, count| [status, count] }

        LinearCli::UI::TableRenderer.output_table(
          'Issues by Status:',
          headers,
          rows,
          widths: { 'Status' => 25, 'Count' => 10 }
        )
      end

      # Display team distribution table
      # @param team_data [Hash] Team counts
      # @return [void]
      def self.display_team_table(team_data)
        headers = %w[Team Count]
        rows = team_data.map { |team, count| [team, count] }

        LinearCli::UI::TableRenderer.output_table(
          'Issues by Team:',
          headers,
          rows,
          widths: { 'Team' => 20, 'Count' => 12 }
        )
      end

      # Display completion rates table
      # @param completion_data [Hash] Completion rate data
      # @return [void]
      def self.display_completion_table(completion_data)
        headers = ['Team', 'Completed', 'Total', 'Rate (%)']
        rows = completion_data.map do |team, data|
          [team, data[:completed], data[:total], data[:rate]]
        end

        LinearCli::UI::TableRenderer.output_table(
          'Team Completion Rates:',
          headers,
          rows,
          widths: { 'Team' => 15, 'Completed' => 12, 'Total' => 12, 'Rate (%)' => 12 }
        )
      end

      # Display capitalization metrics
      # @param capitalization_data [Hash] Capitalization metrics data
      # @param options [Hash] Display options
      def self.display_capitalization_metrics(capitalization_data, options = {})
        return puts 'No capitalization data available.'.yellow unless capitalization_data&.any?

        display_overall_capitalization_rate(capitalization_data) if capitalization_data[:capitalization_rate]

        display_capitalized_projects(capitalization_data) if capitalization_data[:capitalized_projects]&.any?

        display_team_capitalization(capitalization_data) if capitalization_data[:team_capitalization]&.any?

        display_project_engineer_workload(capitalization_data) if capitalization_data[:project_engineer_workload]&.any?

        display_engineer_workload_summary(capitalization_data) if capitalization_data[:engineer_workload]&.any?
      end

      # Display the overall capitalization rate
      # @param capitalization_data [Hash] Capitalization metrics data
      def self.display_overall_capitalization_rate(capitalization_data)
        puts "\n#{'Overall Capitalization Rate:'.bold}"
        puts "  #{format_percentage(capitalization_data[:capitalization_rate])} of issues (#{capitalization_data[:capitalized_count]}/#{capitalization_data[:total_issues]}) are on capitalized projects"
      end

      # Display the list of capitalized projects
      # @param capitalization_data [Hash] Capitalization metrics data
      def self.display_capitalized_projects(capitalization_data)
        puts "\n#{'Capitalized Projects:'.bold}"
        capitalization_data[:capitalized_projects].each do |project|
          puts "  - #{project[:name]}".green
        end
      end

      # Display team capitalization metrics
      # @param capitalization_data [Hash] Capitalization metrics data
      def self.display_team_capitalization(capitalization_data)
        puts "\n#{'Team Capitalization Rates:'.bold}"

        rows = []
        capitalization_data[:team_capitalization].each do |team, metrics|
          rows << [
            team,
            metrics[:capitalized],
            metrics[:non_capitalized],
            metrics[:total],
            format_percentage(metrics[:percentage])
          ]
        end

        # Sort by percentage descending
        rows = rows.sort_by { |row| -row[4].to_f }

        table = Terminal::Table.new(
          headings: ['Team', 'Capitalized', 'Non-Cap', 'Total', 'Cap %'],
          rows: rows
        )

        puts table.render(:unicode, padding: [0, 1], resize: false) do |renderer|
          renderer.width = [20, 30, 15, 15]
        end
      end

      # Display engineers grouped by capitalized projects
      # @param capitalization_data [Hash] Capitalization metrics data
      def self.display_project_engineer_workload(capitalization_data)
        return if capitalization_data[:project_engineer_workload].empty?

        puts "\n#{'Engineers by Capitalized Project:'.bold}"

        capitalization_data[:project_engineer_workload].each do |project_name, project_data|
          puts "\n  #{'Project:'.bold} #{project_name.green} (#{project_data[:assigned_issues]}/#{project_data[:total_issues]} assigned issues)"

          # Skip if no engineers on this project
          next if project_data[:engineers].empty?

          # Build table of engineers for this project
          rows = []
          project_data[:engineers].each_value do |engineer|
            rows << [
              engineer[:name],
              engineer[:email],
              engineer[:issues_count],
              engineer[:total_estimate]
            ]
          end

          # Sort by issue count descending
          rows = rows.sort_by { |row| -row[2] }

          table = Terminal::Table.new(
            headings: ['Engineer', 'Email', 'Issues', 'Est. Points'],
            rows: rows
          )

          puts table.render(:unicode, padding: [0, 1], resize: false) do |renderer|
            renderer.width = [20, 12, 10, 12, 12, 12, 15]
          end

          # If in test mode, also show issues for each engineer
          next unless ENV['LINEAR_CLI_TEST']

          puts "\n    #{'Issues by Engineer:'.bold}"
          project_data[:engineers].each_value do |engineer|
            puts "    - #{engineer[:name]}:".green
            engineer[:issues].each do |issue|
              status = if issue[:completed_at]
                         'Done'
                       else
                         (issue[:started_at] ? 'In Progress' : 'Not Started')
                       end
              puts "      ∙ #{issue[:title]} (#{issue[:estimate] || 'no'} points) - #{status}"
            end
          end
        end
      end

      # Display engineer workload summary
      # @param capitalization_data [Hash] Capitalization metrics data
      def self.display_engineer_workload_summary(capitalization_data)
        puts "\n#{'Engineer Workload Summary:'.bold}"

        rows = []
        capitalization_data[:engineer_workload].each do |engineer, metrics|
          rows << [
            engineer,
            metrics[:capitalized_issues],
            metrics[:total_issues],
            format_percentage(metrics[:percentage]),
            metrics[:capitalized_estimate],
            metrics[:total_estimate],
            format_percentage(metrics[:estimate_percentage])
          ]
        end

        # Sort by percentage descending
        rows = rows.sort_by { |row| -row[3].to_f }

        table = Terminal::Table.new(
          headings: ['Engineer', 'Cap Issues', 'Total', 'Cap %', 'Cap Points', 'Total Points', 'Cap Points %'],
          rows: rows
        )

        puts table.render(:unicode, padding: [0, 1], resize: false) do |renderer|
          renderer.width = [20, 12, 10, 12, 12, 12, 15]
        end
      end

      # Format a percentage value
      # @param percentage [Float] Percentage value
      # @return [String] Formatted and colored percentage string
      def self.format_percentage(percentage)
        color = if percentage >= 75
                  :green
                elsif percentage >= 50
                  :yellow
                else
                  :red
                end

        "#{percentage}%".colorize(color)
      end
    end
  end
end
