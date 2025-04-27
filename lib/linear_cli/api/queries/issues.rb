module LinearCli
  module API
    module Queries
      # GraphQL queries for Linear issues
      module Issues
        # Query to list issues with filters
        # @return [String] GraphQL query
        def self.list_issues
          <<~GRAPHQL
            query Issues($teamId: ID, $assigneeId: ID, $states: [ID!], $first: Int, $after: String) {
              issues(
                first: $first
                after: $after
                filter: {
                  team: { id: { eq: $teamId } }
                  assignee: { id: { eq: $assigneeId } }
                  state: { id: { in: $states } }
                }
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

        # Query to get the total count of issues with filters
        # @return [String] GraphQL query
        def self.count_issues
          <<~GRAPHQL
            query IssuesCount($teamId: ID, $assigneeId: ID, $states: [ID!]) {
              issues(
                filter: {
                  team: { id: { eq: $teamId } }
                  assignee: { id: { eq: $assigneeId } }
                  state: { id: { in: $states } }
                }
              ) {
                pageInfo {
                  hasNextPage
                }
                nodes {
                  id
                }
              }
            }
          GRAPHQL
        end

        # Query to get issue details by id
        # @return [String] GraphQL query
        def self.get_issue
          <<~GRAPHQL
            query Issue($id: ID!) {
              issue(id: $id) {
                id
                identifier
                title
                description
                state {
                  id
                  name
                  color
                }
                assignee {
                  id
                  name
                  email
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
                labels {
                  nodes {
                    id
                    name
                    color
                  }
                }
                comments {
                  nodes {
                    id
                    body
                    user {
                      name
                    }
                    createdAt
                  }
                }
                createdAt
                updatedAt
              }
            }
          GRAPHQL
        end

        # Mutation to create a new issue
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
                  url
                }
              }
            }
          GRAPHQL
        end

        # Mutation to update an issue
        # @return [String] GraphQL query
        def self.update_issue
          <<~GRAPHQL
            mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
              issueUpdate(id: $id, input: $input) {
                success
                issue {
                  id
                  identifier
                  title
                  url
                }
              }
            }
          GRAPHQL
        end

        # Mutation to create a comment on an issue
        # @return [String] GraphQL query
        def self.create_comment
          <<~GRAPHQL
            mutation CreateComment($issueId: String!, $body: String!) {
              commentCreate(input: { issueId: $issueId, body: $body }) {
                success
                comment {
                  id
                  body
                }
              }
            }
          GRAPHQL
        end
      end
    end
  end
end
