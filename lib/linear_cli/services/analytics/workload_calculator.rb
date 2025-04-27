module LinearCli
  module Services
    module Analytics
      # Service to calculate engineer workload across projects
      class WorkloadCalculator
        # Calculate engineer workload across projects
        # @param issues [Array<Hash>] Array of issue data
        # @param teams [Array<Hash>] Array of team data
        # @param projects [Array<Hash>] Array of project data
        # @return [Hash] Engineer workload data
        def calculate_engineer_project_workload(issues, teams, _projects)
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

          # Process each issue
          issues.each do |issue|
            # Skip issues without teams or estimates
            next unless issue['team'] && issue['estimate']

            team_id = issue['team']['id']
            issue['team']['name']
            project_id = issue['project'] ? issue['project']['id'] : 'no_project'
            project_name = issue['project'] ? issue['project']['name'] : 'No Project'
            engineer_id = issue['assignee'] ? issue['assignee']['id'] : 'unassigned'
            engineer_name = issue['assignee'] ? issue['assignee']['name'] : 'Unassigned'
            points = issue['estimate'].to_i

            # Skip if points is zero
            next if points.zero?

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
                project[:percentage] = calculate_percentage(project[:points], engineer[:total_points])
              end
            end

            team[:projects].each_value do |project|
              project[:engineers].each_value do |engineer|
                engineer[:percentage] = calculate_percentage(engineer[:points], project[:total_points])
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
