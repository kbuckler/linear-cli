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

      # Calculate capitalization metrics from issues
      # @param issues [Array<Hash>] Array of issues to analyze
      # @param capitalization_labels [Array<String>] Project labels that indicate capitalization
      # @return [Hash] Capitalization metrics
      def self.calculate_capitalization_metrics(issues,
                                                capitalization_labels = ['capitalization', 'capex', 'fixed asset'])
        return {} unless issues&.any?

        # Extract projects that have capitalization labels
        all_projects = issues.map { |i| i[:project] }.compact.uniq

        capitalized_projects = all_projects.select do |project|
          next false unless project[:labels]&.any?

          project[:labels].any? do |label|
            capitalization_labels.include?(label[:name].downcase)
          end
        end

        capitalized_project_ids = capitalized_projects.map { |p| p[:id] }
        capitalized_project_names = capitalized_projects.map { |p| p[:name] }

        # Filter issues into capitalized vs non-capitalized
        capitalized_issues = issues.select { |i| i[:project] && capitalized_project_ids.include?(i[:project][:id]) }
        non_capitalized_issues = issues - capitalized_issues

        capitalized_count = capitalized_issues.size
        non_capitalized_count = non_capitalized_issues.size
        total_issues = issues.size
        capitalization_rate = total_issues.zero? ? 0 : ((capitalized_count.to_f / total_issues) * 100).round(2)

        # Calculate team capitalization metrics
        team_capitalization = calculate_team_capitalization(capitalized_issues, non_capitalized_issues)

        # Calculate engineer workload metrics
        engineer_workload = calculate_engineer_workload(issues, capitalized_project_ids)

        # Group engineers by capitalized project
        project_engineer_workload = calculate_project_engineer_workload(issues, capitalized_projects)

        {
          capitalized_count: capitalized_count,
          non_capitalized_count: non_capitalized_count,
          total_issues: total_issues,
          capitalization_rate: capitalization_rate,
          team_capitalization: team_capitalization,
          engineer_workload: engineer_workload,
          capitalized_projects: capitalized_projects.map { |p| { id: p[:id], name: p[:name] } },
          project_engineer_workload: project_engineer_workload
        }
      end

      # Calculate team capitalization metrics
      # @param capitalized_issues [Array<Hash>] Array of capitalized issues
      # @param non_capitalized_issues [Array<Hash>] Array of non-capitalized issues
      # @return [Hash] Team capitalization metrics
      def self.calculate_team_capitalization(capitalized_issues, non_capitalized_issues)
        teams = {}

        # Process capitalized issues
        capitalized_issues.each do |issue|
          team_name = issue.dig(:team, :name) || 'Unassigned'
          teams[team_name] ||= { capitalized: 0, non_capitalized: 0 }
          teams[team_name][:capitalized] += 1
        end

        # Process non-capitalized issues
        non_capitalized_issues.each do |issue|
          team_name = issue.dig(:team, :name) || 'Unassigned'
          teams[team_name] ||= { capitalized: 0, non_capitalized: 0 }
          teams[team_name][:non_capitalized] += 1
        end

        # Calculate totals and percentages
        teams.each do |team, counts|
          total = counts[:capitalized] + counts[:non_capitalized]
          counts[:total] = total
          counts[:percentage] = total.zero? ? 0 : ((counts[:capitalized].to_f / total) * 100).round(2)
        end

        teams
      end

      # Calculate engineer workload metrics
      # @param issues [Array<Hash>] Array of issues to analyze
      # @param capitalized_project_ids [Array<String>] Array of capitalized project IDs
      # @return [Hash] Engineer workload metrics
      def self.calculate_engineer_workload(issues, capitalized_project_ids)
        engineers = {}

        issues.each do |issue|
          # Skip issues without an assignee
          next unless issue[:assignee]

          engineer_name = issue[:assignee][:name] || 'Unassigned'
          engineers[engineer_name] ||= {
            total_issues: 0,
            capitalized_issues: 0,
            total_estimate: 0,
            capitalized_estimate: 0
          }

          engineers[engineer_name][:total_issues] += 1
          engineers[engineer_name][:total_estimate] += issue[:estimate].to_i

          if issue[:project] && capitalized_project_ids.include?(issue[:project][:id])
            engineers[engineer_name][:capitalized_issues] += 1
            engineers[engineer_name][:capitalized_estimate] += issue[:estimate].to_i
          end
        end

        # Calculate percentages
        engineers.each do |_name, stats|
          stats[:percentage] =
            stats[:total_issues].zero? ? 0 : ((stats[:capitalized_issues].to_f / stats[:total_issues]) * 100).round(2)
          stats[:estimate_percentage] =
            stats[:total_estimate].zero? ? 0 : ((stats[:capitalized_estimate].to_f / stats[:total_estimate]) * 100).round(2)
        end

        engineers
      end

      # Calculate project engineer workload
      # @param issues [Array<Hash>] Array of issues to analyze
      # @param capitalized_projects [Array<Hash>] Array of capitalized projects
      # @return [Hash] Project engineer workload data
      def self.calculate_project_engineer_workload(issues, capitalized_projects)
        result = {}

        # Initialize project data structure
        capitalized_projects.each do |project|
          result[project[:name]] = {
            id: project[:id],
            total_issues: 0,
            assigned_issues: 0,
            engineers: {}
          }
        end

        # Process issues
        issues.each do |issue|
          next unless issue[:project]

          project = capitalized_projects.find { |p| p[:id] == issue[:project][:id] }
          next unless project

          project_name = project[:name]
          result[project_name][:total_issues] += 1

          # Skip issues without an assignee
          next unless issue[:assignee]

          result[project_name][:assigned_issues] += 1

          engineer_id = issue[:assignee][:id]
          engineer_name = issue[:assignee][:name]
          engineer_email = issue[:assignee][:email]

          # Initialize engineer data if not exists
          result[project_name][:engineers][engineer_id] ||= {
            id: engineer_id,
            name: engineer_name,
            email: engineer_email,
            issues_count: 0,
            total_estimate: 0,
            issues: []
          }

          # Update engineer data
          result[project_name][:engineers][engineer_id][:issues_count] += 1
          result[project_name][:engineers][engineer_id][:total_estimate] += issue[:estimate].to_i
          result[project_name][:engineers][engineer_id][:issues] << {
            id: issue[:id],
            title: issue[:title],
            estimate: issue[:estimate],
            started_at: issue[:startedAt],
            completed_at: issue[:completedAt]
          }
        end

        result
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
