module LinearCli
  module Analytics
    # Reporting functionality for Linear data analysis
    module Reporting
      # Count issues by status
      # @param issues [Array<Hash>] List of issues
      # @return [Hash] Counts of issues by status
      def self.count_issues_by_status(issues)
        issues.each_with_object(Hash.new(0)) do |issue, counts|
          status = issue.dig('state', 'name') || 'Unknown'
          counts[status] += 1
        end
      end

      # Count issues by team
      # @param issues [Array<Hash>] List of issues
      # @return [Hash] Counts of issues by team
      def self.count_issues_by_team(issues)
        issues.each_with_object(Hash.new(0)) do |issue, counts|
          team = issue.dig('team', 'name') || 'Unknown'
          counts[team] += 1
        end
      end

      # Calculate team completion rates
      # @param issues [Array<Hash>] List of issues
      # @return [Hash] Team completion rates
      def self.calculate_team_completion_rates(issues)
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

      # Calculate software capitalization metrics on a per-project basis
      # @param issues [Array<Hash>] List of issues
      # @param projects [Array<Hash>] List of projects
      # @param labels [Array<String>] List of capitalization labels to identify capitalized projects
      # @return [Hash] Capitalization metrics
      def self.calculate_capitalization_metrics(issues, projects = [],
                                                labels = ['capitalization', 'capex', 'fixed asset'])
        # Identify capitalized projects by their labels
        capitalized_projects = projects.select do |project|
          next false unless project['labels'] && project['labels']['nodes']

          project['labels']['nodes'].any? do |label|
            labels.any? { |cap_label| label['name'].downcase.include?(cap_label.downcase) }
          end
        end

        capitalized_project_ids = capitalized_projects.map { |p| p['id'] }
        capitalized_project_names = capitalized_projects.map { |p| p['name'] }

        # Filter issues based on whether they belong to capitalized projects
        capitalized_issues = issues.select do |issue|
          issue.dig('project', 'id') && capitalized_project_ids.include?(issue.dig('project', 'id'))
        end

        non_capitalized_issues = issues - capitalized_issues

        # Calculate team capitalization metrics
        team_capitalization = issues
                              .group_by { |i| i.dig('team', 'name') || 'Unknown' }
                              .transform_values do |team_issues|
          team_capitalized_issues = team_issues.select do |issue|
            capitalized_issues.any? { |cap_issue| cap_issue['id'] == issue['id'] }
          end

          capitalized = team_capitalized_issues.size
          total = team_issues.size

          {
            capitalized: capitalized,
            non_capitalized: total - capitalized,
            total: total,
            capitalization_rate: total > 0 ? (capitalized.to_f / total * 100).round(2) : 0
          }
        end

        # Calculate engineer workload metrics
        engineer_workload = {}

        # Group issues by assignee
        assignee_issues = issues.reject { |i| i['assignee'].nil? }
                                .group_by { |i| i['assignee']['name'] }

        assignee_issues.each do |engineer_name, eng_issues|
          # Calculate how many issues are for capitalized projects
          eng_capitalized_issues = eng_issues.select do |issue|
            issue.dig('project', 'id') && capitalized_project_ids.include?(issue.dig('project', 'id'))
          end

          total_issues = eng_issues.size
          capitalized_count = eng_capitalized_issues.size

          # Calculate total estimates (if available)
          total_estimate = eng_issues.sum { |i| i['estimate'].to_f }
          capitalized_estimate = eng_capitalized_issues.sum { |i| i['estimate'].to_f }

          # Determine percentage of work on capitalized projects
          cap_percentage = total_issues > 0 ? (capitalized_count.to_f / total_issues * 100).round(2) : 0
          estimate_percentage = total_estimate > 0 ? (capitalized_estimate / total_estimate * 100).round(2) : 0

          engineer_workload[engineer_name] = {
            total_issues: total_issues,
            capitalized_issues: capitalized_count,
            non_capitalized_issues: total_issues - capitalized_count,
            percentage: cap_percentage,
            total_estimate: total_estimate,
            capitalized_estimate: capitalized_estimate,
            estimate_percentage: estimate_percentage
          }
        end

        {
          capitalized_count: capitalized_issues.size,
          non_capitalized_count: non_capitalized_issues.size,
          total_issues: issues.size,
          capitalization_rate: issues.size > 0 ? (capitalized_issues.size.to_f / issues.size * 100).round(2) : 0,
          team_capitalization: team_capitalization,
          capitalized_projects: capitalized_projects.map { |p| { id: p['id'], name: p['name'] } },
          engineer_workload: engineer_workload
        }
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
            team_completion_rates: calculate_team_completion_rates(issues),
            capitalization_metrics: calculate_capitalization_metrics(issues, projects)
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
