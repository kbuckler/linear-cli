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
            # Skip issues without teams
            next unless issue['team']

            # Only consider completed issues as contributions
            next unless issue['completedAt']

            issue_team_id = issue['team']['id']

            # Skip if issue doesn't belong to the target team
            next unless issue_team_id == team_id

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

        private

        # Calculate percentage safely handling zero division
        # @param numerator [Integer] Numerator (points)
        # @param denominator [Integer] Denominator (total points)
        # @return [Float] Percentage rounded to 2 decimal places
        def calculate_percentage(numerator, denominator)
          return 0.0 if denominator.zero?

          ((numerator.to_f / denominator) * 100).round(2)
        end
      end
    end
  end
end
