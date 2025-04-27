# frozen_string_literal: true

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

        # GraphQL query to list all projects
        # @param team_id [String, nil] Team ID to filter projects
        # @return [String] GraphQL query
        def self.list_projects(_team_id = nil)
          <<~GRAPHQL
            query Projects {
              projects(first: 100) {
                nodes {
                  id
                  name
                  description
                  teams {
                    nodes {
                      id
                      name
                    }
                  }
                  state
                  url
                  createdAt
                  updatedAt
                }
              }
            }
          GRAPHQL
        end

        # GraphQL query to list all issues for analytics
        # @param team_id [String, nil] Team ID to filter issues
        # @return [String] GraphQL query
        def self.list_issues(_team_id = nil)
          <<~GRAPHQL
            query Issues($teamId: String, $first: Int, $after: String) {
              issues(
                filter: { team: { id: { eq: $teamId } } }
                first: $first
                after: $after
              ) {
                nodes {
                  id
                  title
                  state {
                    name
                  }
                  team {
                    id
                    name
                  }
                  assignee {
                    id
                    name
                  }
                  project {
                    id
                    name
                  }
                  estimate
                  completedAt
                  createdAt
                }
                pageInfo {
                  hasNextPage
                  endCursor
                }
              }
            }
          GRAPHQL
        end
      end
    end
  end
end
