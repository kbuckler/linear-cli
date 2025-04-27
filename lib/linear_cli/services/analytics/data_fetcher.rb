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
          result = @client.fetch_paginated_data(query, { first: 20 }, {
                                                  fetch_all: true,
                                                  nodes_path: 'teams',
                                                  page_info_path: 'teams'
                                                })
          result || []
        end

        # Fetch projects from the Linear API
        # @return [Array<Hash>] Array of project data
        def fetch_projects
          query = LinearCli::API::Queries::Analytics.list_projects
          result = @client.fetch_paginated_data(query, { first: 20 }, {
                                                  fetch_all: true,
                                                  nodes_path: 'projects',
                                                  page_info_path: 'projects'
                                                })
          result || []
        end

        # Fetch issues from the Linear API
        # @return [Array<Hash>] Array of issue data
        def fetch_issues
          query = LinearCli::API::Queries::Analytics.list_issues
          result = @client.fetch_paginated_data(query, { first: 20 }, {
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
