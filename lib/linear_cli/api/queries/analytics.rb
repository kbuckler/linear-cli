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
        # Note: Projects can belong to multiple teams, but Linear's GraphQL API doesn't
        # support filtering by team directly. Client-side filtering is applied in
        # DataFetcher#fetch_projects after retrieving all projects.
        # @param team_id [String, nil] Team ID used for reference only (not used in query)
        # @return [String] GraphQL query
        def self.list_projects(team_id = nil)
          <<~GRAPHQL
            query Projects($first: Int, $after: String) {
              projects(
                first: $first
                after: $after
              ) {
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
                pageInfo {
                  hasNextPage
                  endCursor
                }
              }
            }
          GRAPHQL
        end

        # GraphQL query to list all issues for analytics
        # Issues belong to exactly one team, so we can filter directly in the API
        # using the teamId parameter.
        # @param team_id [String, nil] Team ID to filter issues
        # @return [String] GraphQL query
        def self.list_issues(team_id = nil)
          <<~GRAPHQL
            query Issues($teamId: ID, $first: Int, $after: String) {
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

        # GraphQL query to fetch team data with nested projects and issues in a single call
        # This optimizes data fetching by pulling all related data in one query
        # @param team_id [String] Team ID to fetch data for
        # @return [String] GraphQL query
        def self.team_workload_data(team_id)
          <<~GRAPHQL
            query TeamWorkloadData($teamId: ID!, $projectsFirst: Int, $projectsAfter: String, $issuesFirst: Int, $issuesAfter: String) {
              team(id: $teamId) {
                id
                name
                key
                description
                projects(first: $projectsFirst, after: $projectsAfter) {
                  nodes {
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
                    url
                    createdAt
                    updatedAt
                  }
                  pageInfo {
                    hasNextPage
                    endCursor
                  }
                }
                issues(first: $issuesFirst, after: $issuesAfter) {
                  nodes {
                    id
                    title
                    state {
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
            }
          GRAPHQL
        end
      end
    end
  end
end
