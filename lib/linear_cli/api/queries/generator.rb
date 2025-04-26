module LinearCli
  module API
    module Queries
      # GraphQL queries for data generation and reporting
      module Generator
        # Query to list teams for data generation
        # @return [String] GraphQL query
        def self.list_teams_for_generator
          <<~GRAPHQL
            query Teams {
              teams {
                nodes {
                  id
                  name
                  key
                  description
                }
              }
            }
          GRAPHQL
        end

        # Query to get team workflow states
        # @return [String] GraphQL query
        def self.get_team_states
          <<~GRAPHQL
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
        end

        # Query to get team members
        # @return [String] GraphQL query
        def self.get_team_members
          <<~GRAPHQL
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
        end

        # Mutation to create a team
        # @return [String] GraphQL query
        def self.create_team
          <<~GRAPHQL
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
        end

        # Mutation to create a project
        # @return [String] GraphQL query
        def self.create_project
          <<~GRAPHQL
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
        end

        # Mutation to create an issue
        # @return [String] GraphQL query
        def self.create_issue
          <<~GRAPHQL
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
                  estimate
                  startedAt
                  completedAt
                  createdAt
                }
              }
            }
          GRAPHQL
        end

        # Query to get all projects for reporting
        # @return [String] GraphQL query
        def self.list_projects_for_reporting
          <<~GRAPHQL
            query Projects {
              projects {
                nodes {
                  id
                  name
                  description
                  state
                  progress
                  labels {
                    nodes {
                      id
                      name
                    }
                  }
                  teams {
                    nodes {
                      id
                      name
                    }
                  }
                  issues {
                    nodes {
                      id
                      identifier
                    }
                  }
                }
              }
            }
          GRAPHQL
        end

        # Query to get all issues for reporting
        # @return [String] GraphQL query
        def self.list_issues_for_reporting
          <<~GRAPHQL
            query {
              issues(first: 100) {
                nodes {
                  id
                  identifier
                  title
                  description
                  state {
                    id
                    name
                    type
                  }
                  assignee {
                    id
                    name
                    email
                  }
                  team {
                    id
                    name
                    key
                  }
                  priority
                  project {
                    id
                    name
                  }
                  labels {
                    nodes {
                      id
                      name
                    }
                  }
                  estimate
                  startedAt
                  completedAt
                  createdAt
                  updatedAt
                }
              }
            }
          GRAPHQL
        end
      end
    end
  end
end
