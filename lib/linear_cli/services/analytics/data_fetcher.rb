# frozen_string_literal: true

module LinearCli
  module Services
    module Analytics
      # Service to fetch analytics data from the Linear API
      class DataFetcher
        # @param client [LinearCli::API::Client] API client to use for requests
        def initialize(client)
          @client = client
        end

        # Fetch a specific team by name from the Linear API
        # @param team_name [String] Name of the team to fetch
        # @return [Hash, nil] Team data or nil if not found
        def fetch_team_by_name(team_name)
          teams = fetch_teams
          teams.find { |team| team['name'].downcase == team_name.downcase }
        end

        # Fetch teams from the Linear API
        # @return [Array<Hash>] Array of team data
        def fetch_teams
          query = LinearCli::API::Queries::Analytics.list_teams
          result = @client.fetch_paginated_data(query, { first: 50 }, {
                                                  fetch_all: true,
                                                  nodes_path: 'teams',
                                                  page_info_path: 'teams'
                                                })
          result || []
        end

        # Fetch projects from the Linear API
        # Projects can belong to multiple teams (many-to-many relationship).
        # Since Linear's GraphQL API doesn't support filtering projects by team directly,
        # we fetch all projects and then filter them on the client side by checking
        # each project's teams collection.
        # @param team_id [String] Optional team ID to filter projects by
        # @return [Array<Hash>] Array of project data
        def fetch_projects(team_id: nil)
          query = LinearCli::API::Queries::Analytics.list_projects(team_id: team_id)
          variables = { first: 50 }

          result = @client.fetch_paginated_data(query, variables, {
                                                  fetch_all: true,
                                                  nodes_path: 'projects',
                                                  page_info_path: 'projects'
                                                })
          result ||= []

          # Filter projects by team_id if provided
          if team_id
            result.select do |project|
              project['teams'] && project['teams']['nodes'] &&
                project['teams']['nodes'].any? { |team| team['id'] == team_id }
            end
          else
            result
          end
        end

        # Fetch issues from the Linear API
        # Issues belong to exactly one team (one-to-many relationship),
        # so we filter them directly in the GraphQL query using the teamId parameter.
        # @param team_id [String] Optional team ID to filter issues by
        # @return [Array<Hash>] Array of issue data
        def fetch_issues(team_id: nil)
          query = LinearCli::API::Queries::Analytics.list_issues(team_id: team_id)
          variables = { first: 50 }
          variables[:teamId] = team_id if team_id

          result = @client.fetch_paginated_data(query, variables, {
                                                  fetch_all: true,
                                                  nodes_path: 'issues',
                                                  page_info_path: 'issues'
                                                })
          result || []
        end

        # Fetch team workload data in a single optimized query
        # This method uses a nested GraphQL query that starts with team as parent
        # and fetches all related projects and issues in one paginated response
        # @param team_id [String] Team ID to fetch data for
        # @return [Hash] Hash containing team data with nested projects and issues
        def fetch_team_workload_data(team_id)
          query = LinearCli::API::Queries::Analytics.team_workload_data(team_id)

          # Initial variables for getting the first page
          variables = {
            teamId: team_id,
            projectsFirst: 50,
            issuesFirst: 50
          }

          if ENV['LINEAR_CLI_DEBUG'] == 'true'
            LinearCli::UI::Logger.info("Fetching team workload data for team ID: #{team_id}")
          end

          # Get initial data
          result = @client.query(query, variables)
          return {} unless result && result['team']

          team_data = result['team']
          projects_data = team_data['projects']['nodes'] || []
          issues_data = team_data['issues']['nodes'] || []

          # Get projects pagination info
          projects_page_info = team_data['projects']['pageInfo'] || {}
          has_more_projects = projects_page_info['hasNextPage'] || false
          projects_cursor = projects_page_info['endCursor']

          # Get issues pagination info
          issues_page_info = team_data['issues']['pageInfo'] || {}
          has_more_issues = issues_page_info['hasNextPage'] || false
          issues_cursor = issues_page_info['endCursor']

          # Fetch additional project pages if needed
          if has_more_projects
            project_pages = fetch_additional_project_pages(team_id, projects_cursor, query)
            projects_data.concat(project_pages) if project_pages.any?
          end

          # Fetch additional issue pages if needed
          if has_more_issues
            issue_pages = fetch_additional_issue_pages(team_id, issues_cursor, query)
            issues_data.concat(issue_pages) if issue_pages.any?
          end

          # Reconstruct the team data with all paginated data
          {
            'id' => team_data['id'],
            'name' => team_data['name'],
            'key' => team_data['key'],
            'description' => team_data['description'],
            'projects' => { 'nodes' => projects_data },
            'issues' => { 'nodes' => issues_data }
          }
        end

        private

        # Helper method to fetch additional project pages
        # @param team_id [String] Team ID
        # @param cursor [String] Pagination cursor
        # @param query [String] GraphQL query
        # @return [Array<Hash>] Additional project data
        def fetch_additional_project_pages(team_id, cursor, query)
          additional_projects = []
          next_cursor = cursor
          has_more = true

          while has_more
            project_vars = {
              teamId: team_id,
              projectsFirst: 50,
              projectsAfter: next_cursor,
              issuesFirst: 0 # Don't fetch issues in project pagination
            }

            # Try to fetch the next page of projects
            begin
              page_result = @client.query(query, project_vars)

              break unless page_result &&
                           page_result['team'] &&
                           page_result['team']['projects'] &&
                           page_result['team']['projects']['nodes']

              # Add the new projects to our collection
              new_projects = page_result['team']['projects']['nodes']
              additional_projects.concat(new_projects)

              # Update pagination info for projects
              projects_page_info = page_result['team']['projects']['pageInfo'] || {}
              has_more = projects_page_info['hasNextPage'] || false
              next_cursor = projects_page_info['endCursor']
            rescue StandardError => e
              LinearCli::UI::Logger.error("Error fetching projects page: #{e.message}")
              break
            end
          end

          additional_projects
        end

        # Helper method to fetch additional issue pages
        # @param team_id [String] Team ID
        # @param cursor [String] Pagination cursor
        # @param query [String] GraphQL query
        # @return [Array<Hash>] Additional issue data
        def fetch_additional_issue_pages(team_id, cursor, query)
          additional_issues = []
          next_cursor = cursor
          has_more = true

          while has_more
            # For issues, create a new separate query that only fetches issues
            # This avoids potential conflicts with the nested query structure
            issue_query = <<~GRAPHQL
              query TeamIssuesPagination($teamId: String!, $issuesFirst: Int, $issuesAfter: String) {
                team(id: $teamId) {
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

            issue_vars = {
              teamId: team_id,
              issuesFirst: 50,
              issuesAfter: next_cursor
            }

            # Try to fetch the next page of issues
            begin
              page_result = @client.query(issue_query, issue_vars)

              break unless page_result &&
                           page_result['team'] &&
                           page_result['team']['issues'] &&
                           page_result['team']['issues']['nodes']

              # Add the new issues to our collection
              new_issues = page_result['team']['issues']['nodes']
              additional_issues.concat(new_issues)

              # Update pagination info for issues
              issues_page_info = page_result['team']['issues']['pageInfo'] || {}
              has_more = issues_page_info['hasNextPage'] || false
              next_cursor = issues_page_info['endCursor']
            rescue StandardError => e
              LinearCli::UI::Logger.error("Error fetching issues page: #{e.message}")
              break
            end
          end

          additional_issues
        end
      end
    end
  end
end
