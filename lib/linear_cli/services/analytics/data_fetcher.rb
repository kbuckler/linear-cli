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
        # @param team_id [String] Optional team ID to filter projects by
        # @return [Array<Hash>] Array of project data
        def fetch_projects(team_id: nil)
          query = LinearCli::API::Queries::Analytics.list_projects(team_id: team_id)
          variables = { first: 50 }
          variables[:teamId] = team_id if team_id

          result = @client.fetch_paginated_data(query, variables, {
                                                  fetch_all: true,
                                                  nodes_path: 'projects',
                                                  page_info_path: 'projects'
                                                })
          result || []
        end

        # Fetch issues from the Linear API
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
      end
    end
  end
end
