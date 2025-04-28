# frozen_string_literal: true

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
        if summary[:issues_by_status].any?
          display_status_table(summary[:issues_by_status])
        end

        # Issues by team
        if summary[:issues_by_team].any?
          display_team_table(summary[:issues_by_team])
        end

        # Team completion rates
        return unless summary[:team_completion_rates].any?

        display_completion_table(summary[:team_completion_rates])
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
          widths: { 'Team' => 15, 'Completed' => 12, 'Total' => 12,
                    'Rate (%)' => 12 }
        )
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
