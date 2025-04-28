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

          # Initial variables for pagination of both projects and issues
          variables = {
            teamId: team_id,
            projectsFirst: 50,
            issuesFirst: 50
          }

          # We need to handle two separate pagination streams (projects and issues)
          # First, get the initial data
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

          # Continue fetching projects if there are more
          while has_more_projects
            variables = {
              teamId: team_id,
              projectsFirst: 50,
              projectsAfter: projects_cursor,
              issuesFirst: 0 # Don't fetch issues in subsequent project pages
            }

            page_result = @client.query(query, variables)
            break unless page_result && page_result['team'] &&
                         page_result['team']['projects'] &&
                         page_result['team']['projects']['nodes']

            # Add the new projects to our collection
            new_projects = page_result['team']['projects']['nodes']
            projects_data.concat(new_projects)

            # Update pagination info
            projects_page_info = page_result['team']['projects']['pageInfo'] || {}
            has_more_projects = projects_page_info['hasNextPage'] || false
            projects_cursor = projects_page_info['endCursor']
          end

          # Now continue fetching issues if there are more
          while has_more_issues
            variables = {
              teamId: team_id,
              projectsFirst: 0, # Don't fetch projects in subsequent issue pages
              issuesFirst: 50,
              issuesAfter: issues_cursor
            }

            page_result = @client.query(query, variables)
            break unless page_result && page_result['team'] &&
                         page_result['team']['issues'] &&
                         page_result['team']['issues']['nodes']

            # Add the new issues to our collection
            new_issues = page_result['team']['issues']['nodes']
            issues_data.concat(new_issues)

            # Update pagination info
            issues_page_info = page_result['team']['issues']['pageInfo'] || {}
            has_more_issues = issues_page_info['hasNextPage'] || false
            issues_cursor = issues_page_info['endCursor']
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
      end
    end
  end
end
