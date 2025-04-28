# frozen_string_literal: true

module LinearCli
  module Services
    module Analytics
      # Service to calculate team workload across projects
      class WorkloadCalculator
        # Calculate team workload across projects for a single team
        # @param issues [Array<Hash>] Array of issue data
        # @param team [Hash] Team data for the target team
        # @param projects [Array<Hash>] Array of project data
        # @return [Hash] Team workload data
        def calculate_team_project_workload(issues, team, projects)
          # Ensure issues is an array to avoid nil errors
          issues = [] if issues.nil?
          projects = [] if projects.nil?

          # Initialize team structure
          team_id = team['id']
          team_name = team['name']

          result = {
            id: team_id,
            name: team_name,
            projects: {},
            contributors: {}
          }

          # Create a project-to-team mapping for faster lookups
          # Each project can belong to multiple teams
          project_team_map = {}
          projects.each do |project|
            project_id = project['id']
            project_team_map[project_id] = []

            # Get teams from the project's teams.nodes array
            next unless project['teams'] && project['teams']['nodes']

            project['teams']['nodes'].each do |proj_team|
              project_team_map[project_id] << proj_team['id']
            end
          end

          # Process each issue
          issues.each do |issue|
            # We need to determine if this issue belongs to our team
            # It can be through direct team association or through project
            issue_belongs_to_team = false

            # Case 1: Issue has team and it matches
            if issue['team'] && issue['team']['id'] == team_id
              issue_belongs_to_team = true
            end

            # Case 2: Issue has project and project belongs to team
            if !issue_belongs_to_team && issue['project']
              project_id = issue['project']['id']
              # Check if this project belongs to our team
              if project_team_map[project_id] && project_team_map[project_id].include?(team_id)
                issue_belongs_to_team = true
              end
            end

            # Skip issues not related to this team
            next unless issue_belongs_to_team

            # Handle project assignment
            if issue['project']
              project_id = issue['project']['id']
              project_name = issue['project']['name']
            else
              project_id = 'no_project'
              project_name = 'No Project'
            end

            # Handle assignee
            contributor_id = issue['assignee'] ? issue['assignee']['id'] : 'unassigned'
            contributor_name = issue['assignee'] ? issue['assignee']['name'] : 'Unassigned'

            # Tasks without estimates should be counted as 1 point of effort
            points = if issue['estimate'].nil? || issue['estimate'].to_i.zero?
                       1
                     else
                       issue['estimate'].to_i
                     end

            # Initialize project if needed
            result[:projects][project_id] ||= {
              name: project_name,
              total_points: 0,
              issues_count: 0,
              contributors: {}
            }

            # Initialize contributor if needed
            result[:contributors][contributor_id] ||= {
              name: contributor_name,
              total_points: 0,
              issues_count: 0,
              projects: {}
            }

            # Initialize contributor in project if needed
            result[:projects][project_id][:contributors][contributor_id] ||= {
              name: contributor_name,
              points: 0,
              issues_count: 0
            }

            # Initialize project in contributor if needed
            result[:contributors][contributor_id][:projects][project_id] ||= {
              name: project_name,
              points: 0,
              issues_count: 0
            }

            # Update points and issue counts
            result[:projects][project_id][:total_points] += points
            result[:projects][project_id][:issues_count] += 1
            result[:projects][project_id][:contributors][contributor_id][:points] += points
            result[:projects][project_id][:contributors][contributor_id][:issues_count] += 1
            result[:contributors][contributor_id][:total_points] += points
            result[:contributors][contributor_id][:issues_count] += 1
            result[:contributors][contributor_id][:projects][project_id][:points] += points
            result[:contributors][contributor_id][:projects][project_id][:issues_count] += 1
          end

          # Calculate percentages
          result[:contributors].each_value do |contributor|
            contributor[:projects].each_value do |project|
              project[:percentage] =
                calculate_percentage(project[:points],
                                     contributor[:total_points])
            end
          end

          result[:projects].each_value do |project|
            project[:contributors].each_value do |contributor|
              contributor[:percentage] =
                calculate_percentage(contributor[:points],
                                     project[:total_points])
            end
          end

          result
        end

        # Backward compatibility method
        # @param issues [Array<Hash>] Array of issue data
        # @param teams [Array<Hash>] Array of team data
        # @param projects [Array<Hash>] Array of project data
        # @return [Hash] Engineer workload data for all teams
        def calculate_engineer_project_workload(issues, teams, projects)
          result = {}

          # Ensure issues is an array to avoid nil errors
          issues = [] if issues.nil?

          # Initialize teams structure
          teams.each do |team|
            team_id = team['id']
            team_name = team['name']

            result[team_id] = {
              name: team_name,
              projects: {},
              engineers: {}
            }
          end

          # Create a project-to-team mapping for faster lookups
          # Each project can belong to multiple teams
          project_team_map = {}
          projects.each do |project|
            project_id = project['id']
            project_team_map[project_id] = []

            # Get teams from the project's teams.nodes array
            next unless project['teams'] && project['teams']['nodes']

            project['teams']['nodes'].each do |team|
              project_team_map[project_id] << team['id']
            end
          end

          # Process each issue
          issues.each do |issue|
            # Skip issues without teams
            next unless issue['team']

            # Only consider completed issues as contributions
            next unless issue['completedAt']

            team_id = issue['team']['id']
            issue['team']['name']

            # Handle project and determine team association
            if issue['project']
              project_id = issue['project']['id']
              project_name = issue['project']['name']

              # Skip if this project doesn't belong to this team
              # NOTE: This is a fallback check since the issue already has a team
              if project_team_map[project_id] && !project_team_map[project_id].empty? &&
                 !project_team_map[project_id].include?(team_id)
                next
              end
            else
              project_id = 'no_project'
              project_name = 'No Project'
            end

            engineer_id = issue['assignee'] ? issue['assignee']['id'] : 'unassigned'
            engineer_name = issue['assignee'] ? issue['assignee']['name'] : 'Unassigned'

            # Tasks without estimates should be counted as 1 point of effort
            points = if issue['estimate'].nil? || issue['estimate'].to_i.zero?
                       1
                     else
                       issue['estimate'].to_i
                     end

            # Initialize project in team if needed
            result[team_id][:projects][project_id] ||= {
              name: project_name,
              total_points: 0,
              engineers: {}
            }

            # Initialize engineer in team if needed
            result[team_id][:engineers][engineer_id] ||= {
              name: engineer_name,
              total_points: 0,
              projects: {}
            }

            # Initialize engineer in project if needed
            result[team_id][:projects][project_id][:engineers][engineer_id] ||= {
              name: engineer_name,
              points: 0
            }

            # Initialize project in engineer if needed
            result[team_id][:engineers][engineer_id][:projects][project_id] ||= {
              name: project_name,
              points: 0
            }

            # Update points
            result[team_id][:projects][project_id][:total_points] += points
            result[team_id][:projects][project_id][:engineers][engineer_id][:points] += points
            result[team_id][:engineers][engineer_id][:total_points] += points
            result[team_id][:engineers][engineer_id][:projects][project_id][:points] += points
          end

          # Calculate percentages
          result.each_value do |team|
            team[:engineers].each_value do |engineer|
              engineer[:projects].each_value do |project|
                project[:percentage] =
                  calculate_percentage(project[:points],
                                       engineer[:total_points])
              end
            end

            team[:projects].each_value do |project|
              project[:engineers].each_value do |engineer|
                engineer[:percentage] =
                  calculate_percentage(engineer[:points],
                                       project[:total_points])
              end
            end
          end

          result
        end

        # Calculate monthly workload data
        # @param issues [Array<Hash>] Array of issue data
        # @return [Hash] Monthly workload data organized by month
        def calculate_monthly_workload(issues)
          # Ensure issues is an array to avoid nil errors
          issues = [] if issues.nil?

          # Initialize result structure
          result = {}

          # Group issues by month based on their completion date
          grouped_issues = issues.group_by do |issue|
            if issue['completedAt']
              Time.parse(issue['completedAt']).strftime('%Y-%m')
            else
              'incomplete'
            end
          end

          # Process each month's worth of issues
          grouped_issues.each do |month, month_issues|
            next if month == 'incomplete' # Skip incomplete issues

            month_name = format_month_name(month)
            monthly_data = {
              month_name: month_name,
              issue_count: month_issues.size,
              contributors: {},
              projects: {}
            }

            # Process each issue in this month
            month_issues.each do |issue|
              # Handle project assignment
              if issue['project']
                project_id = issue['project']['id']
                project_name = issue['project']['name']
              else
                project_id = 'no_project'
                project_name = 'No Project'
              end

              # Handle assignee
              contributor_id = issue['assignee'] ? issue['assignee']['id'] : 'unassigned'
              contributor_name = issue['assignee'] ? issue['assignee']['name'] : 'Unassigned'

              # Tasks without estimates should be counted as 1 point of effort
              points = if issue['estimate'].nil? || issue['estimate'].to_i.zero?
                         1
                       else
                         issue['estimate'].to_i
                       end

              # Initialize contributor if needed
              monthly_data[:contributors][contributor_id] ||= {
                name: contributor_name,
                total_points: 0,
                issues_count: 0,
                projects: {}
              }

              # Initialize project if needed
              monthly_data[:projects][project_id] ||= {
                name: project_name,
                total_points: 0,
                issues_count: 0,
                contributors: {}
              }

              # Initialize contributor in project if needed
              monthly_data[:projects][project_id][:contributors][contributor_id] ||= {
                name: contributor_name,
                points: 0,
                issues_count: 0
              }

              # Initialize project in contributor if needed
              monthly_data[:contributors][contributor_id][:projects][project_id] ||= {
                name: project_name,
                points: 0,
                issues_count: 0
              }

              # Update points and issue counts
              monthly_data[:contributors][contributor_id][:total_points] += points
              monthly_data[:contributors][contributor_id][:issues_count] += 1
              monthly_data[:projects][project_id][:total_points] += points
              monthly_data[:projects][project_id][:issues_count] += 1
              monthly_data[:projects][project_id][:contributors][contributor_id][:points] += points
              monthly_data[:projects][project_id][:contributors][contributor_id][:issues_count] += 1
              monthly_data[:contributors][contributor_id][:projects][project_id][:points] += points
              monthly_data[:contributors][contributor_id][:projects][project_id][:issues_count] += 1
            end

            # Calculate percentages
            monthly_data[:contributors].each_value do |contributor|
              contributor[:projects].each_value do |project|
                project[:percentage] = calculate_percentage(project[:points], contributor[:total_points])
              end
            end

            monthly_data[:projects].each_value do |project|
              project[:contributors].each_value do |contributor|
                contributor[:percentage] = calculate_percentage(contributor[:points], project[:total_points])
              end
            end

            result[month] = monthly_data
          end

          result
        end

        # Calculate project workload data
        # @param issues [Array<Hash>] Array of issue data
        # @param projects [Array<Hash>] Array of project data
        # @return [Hash] Project workload data
        def calculate_project_workload(issues, projects)
          # Use the monthly workload calculation as they share the same structure
          calculate_monthly_workload(issues)
        end

        private

        # Calculate percentage safely handling zero division
        # @param numerator [Integer] Numerator (points)
        # @param denominator [Integer] Denominator (total points)
        # @return [Float] Percentage rounded to 2 decimal places
        def calculate_percentage(numerator, denominator)
          return 0.0 if denominator.zero?

          ((numerator.to_f / denominator) * 100).round(2)
        end

        # Format month name from YYYY-MM format
        # @param month [String] Month in YYYY-MM format
        # @return [String] Formatted month name (e.g., "January 2023")
        def format_month_name(month)
          year, month_num = month.split('-')
          month_names = %w[January February March April May June July August September October November December]
          "#{month_names[month_num.to_i - 1]} #{year}"
        end
      end
    end
  end
end
