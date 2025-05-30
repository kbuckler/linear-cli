# frozen_string_literal: true

module LinearCli
  module API
    module Queries
      # GraphQL queries for Linear teams
      module Teams
        # Query to list teams
        # @return [String] GraphQL query
        def self.list_teams
          <<~GRAPHQL
            query Teams {
              teams {
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

        # Query to get team details by id
        # @return [String] GraphQL query
        def self.team
          <<~GRAPHQL
            query Team($id: String!) {
              team(id: $id) {
                id
                name
                key
                description
                states {
                  nodes {
                    id
                    name
                    color
                    position
                  }
                }
                members {
                  nodes {
                    id
                    name
                    email
                  }
                }
                labels {
                  nodes {
                    id
                    name
                    color
                  }
                }
                cycles {
                  nodes {
                    id
                    name
                    startsAt
                    endsAt
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
