module LinearCli
  module API
    # Data generator for populating Linear with test data
    class DataGenerator
      # Initialize with a Linear API client
      # @param client [LinearCli::API::Client] Linear API client
      def initialize(client)
        @client = client
        @created_teams = []
        @created_projects = []
        @created_issues = []
      end

      # Generate a team
      # @param name [String] Team name
      # @param key [String] Team key (optional)
      # @param description [String] Team description (optional)
      # @return [Hash] Created team data
      def create_team(name, key = nil, description = nil)
        query = <<~GRAPHQL
          mutation CreateTeam($input: TeamCreateInput!) {
            teamCreate(input: $input) {
              success
              team {
                id
                name
                key
                description
              }
            }
          }
        GRAPHQL

        variables = {
          input: {
            name: name
          }
        }

        variables[:input][:key] = key if key
        variables[:input][:description] = description if description

        response = @client.query(query, variables)

        raise "Failed to create team: #{response.inspect}" unless response.dig('teamCreate', 'success')

        team = response.dig('teamCreate', 'team')
        @created_teams << team

        team
      end

      # Generate a project
      # @param name [String] Project name
      # @param team_id [String] Team ID
      # @param description [String] Project description (optional)
      # @param state [String] Project state (optional)
      # @return [Hash] Created project data
      def create_project(name, team_id, description = nil, state = 'started')
        query = <<~GRAPHQL
          mutation CreateProject($input: ProjectCreateInput!) {
            projectCreate(input: $input) {
              success
              project {
                id
                name
                description
                state
                teams {
                  nodes {
                    id
                    name
                  }
                }
              }
            }
          }
        GRAPHQL

        variables = {
          input: {
            name: name,
            teamIds: [team_id],
            state: state
          }
        }

        variables[:input][:description] = description if description

        response = @client.query(query, variables)

        raise "Failed to create project: #{response.inspect}" unless response.dig('projectCreate', 'success')

        project = response.dig('projectCreate', 'project')
        @created_projects << project

        project
      end

      # Generate an issue
      # @param title [String] Issue title
      # @param team_id [String] Team ID
      # @param options [Hash] Additional issue options
      # @option options [String] :description Issue description
      # @option options [String] :assignee_id Assignee ID
      # @option options [String] :state_id State ID
      # @option options [Integer] :priority Priority (0-4)
      # @option options [Array<String>] :label_ids Label IDs
      # @option options [String] :project_id Project ID
      # @return [Hash] Created issue data
      def create_issue(title, team_id, options = {})
        query = <<~GRAPHQL
          mutation CreateIssue($input: IssueCreateInput!) {
            issueCreate(input: $input) {
              success
              issue {
                id
                identifier
                title
                description
                state {
                  id
                  name
                }
                assignee {
                  id
                  name
                }
                team {
                  id
                  name
                }
                priority
                project {
                  id
                  name
                }
              }
            }
          }
        GRAPHQL

        variables = {
          input: {
            title: title,
            teamId: team_id
          }
        }

        # Add optional fields if provided
        variables[:input][:description] = options[:description] if options[:description]
        variables[:input][:assigneeId] = options[:assignee_id] if options[:assignee_id]
        variables[:input][:stateId] = options[:state_id] if options[:state_id]
        variables[:input][:priority] = options[:priority] if options[:priority]
        variables[:input][:labelIds] = options[:label_ids] if options[:label_ids]
        variables[:input][:projectId] = options[:project_id] if options[:project_id]

        response = @client.query(query, variables)

        raise "Failed to create issue: #{response.inspect}" unless response.dig('issueCreate', 'success')

        issue = response.dig('issueCreate', 'issue')
        @created_issues << issue

        issue
      end

      # Get all created teams
      # @return [Array<Hash>] Created teams
      attr_reader :created_teams

      # Get all created projects
      # @return [Array<Hash>] Created projects
      attr_reader :created_projects

      # Get all created issues
      # @return [Array<Hash>] Created issues
      attr_reader :created_issues

      # Get team states (workflow states)
      # @param team_id [String] Team ID
      # @return [Array<Hash>] Team workflow states
      def get_team_states(team_id)
        query = <<~GRAPHQL
          query TeamWorkflowStates($teamId: String!) {
            team(id: $teamId) {
              states {
                nodes {
                  id
                  name
                  description
                  color
                  type
                }
              }
            }
          }
        GRAPHQL

        response = @client.query(query, { teamId: team_id })

        response.dig('team', 'states', 'nodes') || []
      end

      # Get team members
      # @param team_id [String] Team ID
      # @return [Array<Hash>] Team members
      def get_team_members(team_id)
        query = <<~GRAPHQL
          query TeamMembers($teamId: String!) {
            team(id: $teamId) {
              members {
                nodes {
                  id
                  name
                  email
                }
              }
            }
          }
        GRAPHQL

        response = @client.query(query, { teamId: team_id })

        response.dig('team', 'members', 'nodes') || []
      end

      # Generate a complete dataset with teams, projects, and issues
      # @param teams_count [Integer] Number of teams to create
      # @param projects_per_team [Integer] Number of projects per team
      # @param issues_per_project [Integer] Number of issues per project
      # @return [Hash] Summary of created data
      def generate_dataset(teams_count = 2, projects_per_team = 2, issues_per_project = 5)
        results = { teams: [], projects: [], issues: [] }

        # Create teams
        teams_count.times do |i|
          team = create_team("Test Team #{i + 1}", "TT#{i + 1}", "Generated test team #{i + 1}")
          results[:teams] << team

          # Get team states for later use
          states = get_team_states(team['id'])
          members = get_team_members(team['id'])

          # Create projects for this team
          projects_per_team.times do |j|
            project = create_project(
              "Test Project #{i + 1}-#{j + 1}",
              team['id'],
              "Generated test project #{j + 1} for team #{i + 1}"
            )
            results[:projects] << project

            # Create issues for this project
            issues_per_project.times do |k|
              # Assign to random team member if available
              assignee_id = members.sample['id'] if members.any?

              # Use random state if available
              state_id = states.sample['id'] if states.any?

              # Random priority between 0-4
              priority = rand(5)

              issue = create_issue(
                "Test Issue #{i + 1}-#{j + 1}-#{k + 1}",
                team['id'],
                {
                  description: "Generated test issue #{k + 1} for project #{j + 1} in team #{i + 1}",
                  assignee_id: assignee_id,
                  state_id: state_id,
                  priority: priority,
                  project_id: project['id']
                }
              )
              results[:issues] << issue
            end
          end
        end

        # Return summary
        {
          created: {
            teams: results[:teams].size,
            projects: results[:projects].size,
            issues: results[:issues].size
          },
          data: results
        }
      end
    end
  end
end
