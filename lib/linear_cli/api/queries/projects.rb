module LinearCli
  module API
    module Queries
      # GraphQL queries for Linear projects
      module Projects
        # Query to list projects
        # @return [String] GraphQL query
        def self.list_projects
          <<~GRAPHQL
            query Projects {
              projects {
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
                  lead {
                    id
                    name
                  }
                  targetDate
                  startDate
                  progress
                }
              }
            }
          GRAPHQL
        end

        # Query to get project details by id
        # @return [String] GraphQL query
        def self.project
          <<~GRAPHQL
            query Project($id: ID!) {
              project(id: $id) {
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
                lead {
                  id
                  name
                }
                members {
                  nodes {
                    id
                    name
                  }
                }
                issues {
                  nodes {
                    id
                    identifier
                    title
                    state {
                      name
                    }
                  }
                }
                targetDate
                startDate
                progress
                updatedAt
                createdAt
              }
            }
          GRAPHQL
        end
      end
    end
  end
end
