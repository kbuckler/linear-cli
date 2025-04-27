module LinearCli
  module API
    module Queries
      # GraphQL queries for Linear analytics
      module Analytics
        # Query to list teams with pagination
        # @return [String] GraphQL query
        def self.list_teams
          <<~GRAPHQL
            query Teams($first: Int, $after: String) {
              teams(first: $first, after: $after) {
                pageInfo {
                  hasNextPage
                  endCursor
                }
                nodes {
                  id
                  name
                  key
                  description
                  states {
                    nodes {
                      id
                      name
                      color
                    }
                  }
                  members {
                    nodes {
                      id
                      name
                      email
                    }
                  }
                }
              }
            }
          GRAPHQL
        end

        # Query to list projects with pagination
        # @return [String] GraphQL query
        def self.list_projects(team_id: nil)
          <<~GRAPHQL
            query Projects($first: Int, $after: String) {
              projects(first: $first, after: $after) {
                pageInfo {
                  hasNextPage
                  endCursor
                }
                nodes {
                  id
                  name
                  description
                  state
                  startDate
                  targetDate
                  completedAt
                  createdAt
                  updatedAt
                  teams {
                    nodes {
                      id
                      name
                    }
                  }
                  lead {
                    id
                    name
                  }
                  members {
                    nodes {
                      id
                      name
                      email
                    }
                  }
                }
              }
            }
          GRAPHQL
        end

        # Query to list issues with pagination
        # @return [String] GraphQL query
        def self.list_issues(team_id: nil)
          <<~GRAPHQL
            query Issues($first: Int, $after: String, $teamId: ID) {
              issues(
                first: $first,
                after: $after,
                filter: { team: { id: { eq: $teamId } } }
              ) {
                pageInfo {
                  hasNextPage
                  endCursor
                }
                nodes {
                  id
                  identifier
                  title
                  state {
                    id
                    name
                    color
                  }
                  assignee {
                    id
                    name
                  }
                  team {
                    id
                    name
                  }
                  project {
                    id
                    name
                  }
                  priority
                  estimate
                  startedAt
                  completedAt
                  cycle {
                    id
                    name
                  }
                  labels {
                    nodes {
                      name
                    }
                  }
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
