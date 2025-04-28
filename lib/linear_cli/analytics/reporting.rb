# frozen_string_literal: true

module LinearCli
  module Analytics
    # Reporting functionality for Linear data analysis
    module Reporting
      # Count issues by status
      # @param issues [Array<Hash>] List of issues
      # @return [Hash] Counts of issues by status
      def self.count_issues_by_status(issues)
        issues.each_with_object(Hash.new(0)) do |issue, counts|
          status = issue.dig('state',
                             'name') || issue.dig(:state, :name) || 'Unknown'
          counts[status] += 1
        end
      end

      # Count issues by team
      # @param issues [Array<Hash>] List of issues
      # @return [Hash] Counts of issues by team
      def self.count_issues_by_team(issues)
        issues.each_with_object(Hash.new(0)) do |issue, counts|
          team = issue.dig('team',
                           'name') || issue.dig(:team, :name) || 'Unknown'
          counts[team] += 1
        end
      end

      # Calculate team completion rates
      # @param issues [Array<Hash>] List of issues
      # @return [Hash] Team completion rates
      def self.calculate_team_completion_rates(issues)
        team_issues = issues.group_by do |i|
          i.dig('team', 'name') || i.dig(:team, :name) || 'Unknown'
        end

        team_issues.transform_values do |team_issues_list|
          total = team_issues_list.size
          completed = team_issues_list.count do |i|
            i['completedAt'] || i[:completedAt]
          end
          {
            total: total,
            completed: completed,
            rate: total.positive? ? (completed.to_f / total * 100).round(2) : 0
          }
        end
      end

      # Generate complete report from workspace data
      # @param teams [Array<Hash>] Teams data
      # @param projects [Array<Hash>] Projects data
      # @param issues [Array<Hash>] Issues data
      # @return [Hash] Complete report data
      def self.generate_report(teams, projects, issues)
        {
          teams: teams,
          projects: projects,
          issues: issues,
          summary: {
            teams_count: teams.size,
            projects_count: projects.size,
            issues_count: issues.size,
            issues_by_status: count_issues_by_status(issues),
            issues_by_team: count_issues_by_team(issues),
            team_completion_rates: calculate_team_completion_rates(issues)
          }
        }
      end

      # Format a table row for displaying in terminal
      # @param values [Array] Row values
      # @return [String] Formatted row
      def self.format_table_row(values)
        values.join(' | ')
      end

      # Format a summary table header
      # @param headers [Array<String>] Table headers
      # @return [String] Formatted header row
      def self.format_table_header(headers)
        header_row = format_table_row(headers)
        separator = headers.map { |h| '-' * h.length }.join('-+-')
        "#{header_row}\n#{separator}"
      end

      # Display simple text table (for test environments)
      # @param headers [Array<String>] Table headers
      # @param rows [Array<Array>] Table data rows
      # @return [String] Complete table as string
      def self.format_simple_table(headers, rows)
        result = [format_table_header(headers)]
        rows.each do |row|
          result << format_table_row(row)
        end
        result.join("\n")
      end
    end
  end
end
