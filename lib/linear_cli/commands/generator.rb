require 'thor'
require 'tty-table'
require 'json'
require_relative '../api/data_generator'
require_relative '../api/queries/generator'
require_relative '../analytics/display'

module LinearCli
  module Commands
    # Commands related to generating data for Linear
    class Generator < Thor
      desc 'populate', 'Populate Linear with generated test data'
      long_desc <<-LONGDESC
        Populates your Linear workspace with test data for development and testing purposes.

        This command creates projects and issues for existing teams in your Linear workspace.
        You can control the amount of data generated with options to specify the number of teams,
        projects per team, and issues per project.

        The generated data includes story points and historical data (across 6 months),
        making it ideal for testing the engineer workload reports.

        Example:
          linear generator populate --teams=3 --projects_per_team=2 --issues_per_project=10
      LONGDESC
      option :teams,
             type: :numeric,
             desc: 'Number of teams to create',
             default: 2,
             required: false
      option :projects_per_team,
             type: :numeric,
             desc: 'Number of projects per team',
             default: 3,
             required: false
      option :issues_per_project,
             type: :numeric,
             desc: 'Number of issues per project',
             default: 10,
             required: false
      option :months,
             type: :numeric,
             desc: 'Number of months to backdate issues (1-6)',
             default: 6,
             required: false
      option :with_workload_data,
             type: :boolean,
             desc: 'Generate data optimized for workload analysis',
             default: true,
             required: false
      option :assign_to_users,
             type: :boolean,
             desc: 'Assign issues to actual users on the account',
             default: true,
             required: false
      option :assignment_percentage,
             type: :numeric,
             desc: 'Percentage of issues to assign to actual users (0-100)',
             default: 70,
             required: false
      option :debug,
             type: :boolean,
             desc: 'Enable debug mode with verbose logging',
             default: false,
             required: false
      def populate
        # Validate inputs
        teams_count = sanitize_integer(options[:teams], 1, 5)
        projects_per_team = sanitize_integer(options[:projects_per_team], 1, 5)
        issues_per_project = sanitize_integer(options[:issues_per_project], 1, 20)
        months_of_data = sanitize_integer(options[:months], 1, 6)
        with_workload_data = options[:with_workload_data]
        assign_to_users = options[:assign_to_users]
        assignment_percentage = sanitize_integer(options[:assignment_percentage], 0, 100)
        debug_mode = options[:debug]

        # Enable debug logging if requested
        ENV['LINEAR_CLI_DEBUG'] = 'true' if debug_mode

        if debug_mode
          puts 'DEBUG MODE ENABLED'
          puts "Teams: #{teams_count}"
          puts "Projects per team: #{projects_per_team}"
          puts "Issues per project: #{issues_per_project}"
          puts "Months of data: #{months_of_data}"
          puts "Workload data: #{with_workload_data}"
          puts "Assign to users: #{assign_to_users}"
          puts "Assignment percentage: #{assignment_percentage}%"
        end

        # Initialize client
        client = LinearCli::API::Client.new

        # Try to fetch existing teams first
        existing_teams = fetch_existing_teams(client)

        if existing_teams.empty?
          puts 'No existing teams found. Please create at least one team in Linear first.'
          return
        end

        # Use the data generator
        puts 'Using existing teams from your Linear workspace...'
        generator = LinearCli::API::DataGenerator.new(client)

        results = { teams: [], projects: [], issues: [] }
        teams_to_use = existing_teams.take(teams_count)

        # Collect all actual team members from the teams if assigning to real users
        all_team_members = []
        if assign_to_users
          puts "\nFetching team members for assignment..." if debug_mode
          teams_to_use.each do |team|
            members = generator.get_team_members(team['id'])
            if members.any?
              all_team_members.concat(members)
              puts "Found #{members.size} members in team #{team['name']}" if debug_mode
            end
          rescue StandardError => e
            puts "Warning: Could not fetch team members. #{e.message}" if debug_mode
          end

          if all_team_members.empty?
            puts 'Warning: No team members found. Using fictional engineers instead.'
            assign_to_users = false
          else
            puts "Found #{all_team_members.size} total team members for assignment" if debug_mode
            # Remove duplicates (in case a user is in multiple teams)
            all_team_members.uniq! { |member| member['id'] }
            puts "Using #{all_team_members.size} unique team members for assignment" if debug_mode
          end
        end

        # Generate fictional engineer names for use across teams
        engineers = [
          { name: 'Alice Chen', email: 'alice@example.com' },
          { name: 'Bob Smith', email: 'bob@example.com' },
          { name: 'Charlie Patel', email: 'charlie@example.com' },
          { name: 'Diana Wong', email: 'diana@example.com' },
          { name: 'Ethan Brown', email: 'ethan@example.com' },
          { name: 'Fatima Khan', email: 'fatima@example.com' }
        ]

        # Define story point values to use
        story_points = [1, 2, 3, 5, 8, 13]

        # Generate team data first
        all_projects = []

        puts "\nCreating projects for #{teams_to_use.size} teams..."
        teams_to_use.each do |team|
          results[:teams] << team
          team_projects = []

          # Create projects for this team
          projects_per_team.times do |j|
            project = generator.create_project(
              "Project #{team['key']}-#{j + 1}",
              team['id'],
              "Test project #{j + 1} for team #{team['name']}"
            )
            results[:projects] << project
            team_projects << project
            all_projects << project
          rescue StandardError => e
            puts "Warning: Could not create project. #{e.message}"
          end
        end

        # Now generate issues with a good distribution across engineers and time
        puts "\nCreating issues with engineer assignments and story points..."

        # Calculate date ranges for backdating issues
        now = Time.now
        month_ranges = []
        months_of_data.times do |i|
          start_date = now - (i + 1) * 30 * 24 * 60 * 60
          month_ranges << start_date
        end

        # Group engineers by team for more realistic assignments
        # But also have some engineers work across teams for cross-team analysis
        teams_to_use.each_with_index do |team, team_index|
          team_projects = results[:projects].select { |p| p['teams']['nodes'].any? { |t| t['id'] == team['id'] } }
          next if team_projects.empty?

          # If using real team members, get the ones for this team
          team_members = []
          if assign_to_users
            begin
              team_members = generator.get_team_members(team['id'])
              if team_members.empty? && all_team_members.any?
                # If this team has no members but other teams do, use those
                team_members = all_team_members.sample([3, all_team_members.size].min)
              end
            rescue StandardError => e
              puts "Warning: Could not fetch team members. #{e.message}" if debug_mode
            end
          end

          # Assign some team-specific engineers plus some cross-team engineers
          team_engineers = engineers.sample(3 + team_index % 2)

          # Get workflow states for this team
          workflow_states = generator.get_team_states(team['id'])

          # Find done/completed states
          done_states = workflow_states.select { |s| s['type'] == 'completed' || s['name'].downcase.include?('done') }
          backlog_states = workflow_states.select { |s| s['type'] == 'backlog' || s['name'].downcase.include?('todo') }
          in_progress_states = workflow_states.select do |s|
            s['type'] == 'started' || s['name'].downcase.include?('progress')
          end

          # Default state IDs if specific states cannot be found
          default_done_state = done_states.first&.dig('id')
          default_backlog_state = backlog_states.first&.dig('id')
          default_in_progress_state = in_progress_states.first&.dig('id')

          # For each month in our date range
          month_ranges.each_with_index do |month_date, month_index|
            month_name = month_date.strftime('%B %Y')
            puts "Creating issues for #{team['name']} - #{month_name}..."

            # For each project in this team
            team_projects.each_with_index do |project, project_index|
              # Determine how many issues to create for this project this month
              # More recent months have more issues to show progression
              month_factor = (months_of_data - month_index) / months_of_data.to_f
              month_issues_count = (issues_per_project * month_factor).ceil

              month_issues_count.times do |issue_index|
                # Assign to different engineers with some distribution
                # Some engineers work more on certain projects
                engineer_index = if with_workload_data
                                   # Create patterns in the data
                                   (project_index + issue_index) % team_engineers.size
                                 else
                                   # Random assignment
                                   rand(team_engineers.size)
                                 end
                engineer = team_engineers[engineer_index]

                # Decide whether to assign to a real user or fictional engineer
                real_assignee_id = nil
                if assign_to_users && team_members.any? && rand(100) < assignment_percentage
                  # Select a team member to assign to
                  team_member = team_members.sample
                  real_assignee_id = team_member['id']
                  # Add the team member information to the description for clarity
                  assignee_description = "\nAssigned to actual user: #{team_member['name'] || 'Unknown'} (#{team_member['email'] || 'No email'})"
                else
                  # Use fictional engineer
                  assignee_description = "\nAssigned to fictional engineer: #{engineer[:name]} (#{engineer[:email]})"
                end

                # Story points with some pattern
                # More complex issues for certain projects/engineers
                points = if with_workload_data
                           # Create patterns in the data
                           story_points[(project_index + engineer_index + issue_index) % story_points.size]
                         else
                           # Random points
                           story_points.sample
                         end

                # Create a backdated issue for this month
                issue_date = month_date - rand(1..28) * 24 * 60 * 60
                issue_title = "#{month_date.strftime('%y%m')}-#{team['key']}-#{project_index + 1}-#{issue_index + 1}"

                # Priority varies by team and project
                priority = project_index % 5

                # Set completion status based on month (older issues more likely complete)
                # Older months (lower index) have higher completion probability
                completed = rand < (0.8 - (month_index * 0.1))
                in_progress = !completed && (rand < 0.7)

                # Generate realistic dates
                # Creation date is in the past month
                created_at = issue_date.iso8601
                # Completed date is after creation date, if applicable
                completed_at = completed ? (issue_date + rand(6..20) * 24 * 60 * 60).iso8601 : nil

                # Simplify the state selection to make it more reliable
                # First try to find a completed state for completed issues
                state_id = nil
                if workflow_states.any?
                  state_id = if completed && done_states.any?
                               done_states.first['id']
                             elsif in_progress && in_progress_states.any?
                               in_progress_states.first['id']
                             elsif backlog_states.any?
                               backlog_states.first['id']
                             else
                               # Default to the first state if we can't find a specific one
                               workflow_states.first['id']
                             end
                end

                # Create a simple description with status and date information
                status_text = if completed
                                'COMPLETED'
                              else
                                (in_progress ? 'IN PROGRESS' : 'BACKLOG')
                              end
                description = "Test issue for #{month_name}. Points: #{points}. Status: #{status_text}"

                # Add engineer information
                description += assignee_description

                begin
                  # Create the issue with minimal required fields to avoid API issues
                  # Start with absolutely minimal fields
                  minimal_params = {
                    description: description,
                    project_id: project['id']
                  }

                  # Add the assignee if available
                  minimal_params[:assignee_id] = real_assignee_id if real_assignee_id

                  if debug_mode
                    puts 'Attempting to create issue with minimal fields:'
                    puts "Title: [#{month_date.strftime('%Y-%m')}] #{issue_title}"
                    puts "Team ID: #{team['id']}"
                    puts "Description: #{description}"
                    puts "Project ID: #{project['id']}"
                  end

                  # Create the issue with just the minimal fields
                  issue = generator.create_issue(
                    "[#{month_date.strftime('%Y-%m')}] #{issue_title}",
                    team['id'],
                    minimal_params
                  )

                  results[:issues] << issue
                  puts "Created issue: #{issue['identifier']} - #{issue['title']}"

                  # If we get here, basic creation worked - now we can try updating with more fields
                  begin
                    # Try to update with story points and other fields
                    update_params = {
                      estimate: points,
                      priority: priority
                    }

                    # Only add state_id if we found a valid one
                    # This handles both in-progress and completed states in one update
                    update_params[:state_id] = state_id if state_id

                    # Try to update the state and points
                    updated_issue = generator.update_issue(issue['id'], update_params)
                    if debug_mode
                      puts "Updated issue #{issue['identifier']} with story points: #{points}"
                      if state_id
                        status_type = if completed
                                        'COMPLETED'
                                      elsif in_progress
                                        'IN PROGRESS'
                                      else
                                        'BACKLOG'
                                      end
                        puts "Updated issue #{issue['identifier']} with status: #{status_type}"
                      end
                    end

                    # completedAt is not directly supported in the Linear API update operation
                    # Instead, setting a "completed" state should implicitly mark it as completed
                  rescue StandardError => e
                    puts "Warning: Created issue but couldn't update with additional fields: #{e.message}"
                  end
                rescue StandardError => e
                  puts "Error creating issue: #{e.message}"

                  if debug_mode
                    puts 'Trying even more minimal approach...'
                    begin
                      # Try with just title and team ID
                      super_minimal_issue = generator.create_issue(
                        "[#{month_date.strftime('%Y-%m')}] #{issue_title} - Minimal",
                        team['id'],
                        {}
                      )
                      results[:issues] << super_minimal_issue
                      puts "Created super minimal issue: #{super_minimal_issue['identifier']} - #{super_minimal_issue['title']}"
                    rescue StandardError => e2
                      puts "Even minimal creation failed: #{e2.message}"
                    end
                  end
                end
              end
            end
          end
        end

        # Display results
        puts "\nGeneration complete!"
        puts "Used #{results[:teams].size} teams, created #{results[:projects].size} projects, and #{results[:issues].size} issues."
        puts "Data spans #{months_of_data} months of history and includes story point estimates."

        # Display projects
        LinearCli::Analytics::Display.display_projects(results[:projects]) if results[:projects].any?

        # Provide hint for querying the generated data
        puts "\nYou can now analyze the generated data using the engineer workload report:"
        puts '  linear analytics engineer_workload'
      end

      desc 'dump', 'Dump detailed reporting data from Linear (DEPRECATED)'
      long_desc <<-LONGDESC
        DEPRECATED: This command has been removed.#{' '}

        Please use 'linear analytics report' for comprehensive reporting.

        This command will be removed in a future version.
      LONGDESC
      option :format,
             type: :string,
             desc: 'Output format (json or table)',
             default: 'table',
             required: false
      def dump
        puts 'DEPRECATED: The dump command has been removed.'
        puts 'Please use the following command instead:'
        puts '  linear analytics report         # For comprehensive reports'
        puts '  linear analytics capitalization # For capitalization metrics only'
        puts "\nThis command will be removed in a future version."
      end

      private

      def fetch_existing_teams(client)
        puts 'Fetching existing teams from Linear...'

        query = LinearCli::API::Queries::Generator.list_teams_for_generator
        result = client.query(query)
        teams = result.dig('teams', 'nodes') || []

        puts "Found #{teams.size} teams in your Linear workspace."
        teams
      end

      def sanitize_integer(value, min, max)
        value = value.to_i
        if value < min
          min
        elsif value > max
          max
        else
          value
        end
      end
    end
  end
end
