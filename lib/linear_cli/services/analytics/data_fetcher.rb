module LinearCli
  module Services
    module Analytics
      # Service to fetch analytics data from the Linear API
      class DataFetcher
        # @param client [LinearCli::API::Client] API client to use for requests
        def initialize(client)
          @client = client
        end

        # Fetch teams from the Linear API
        # @return [Array<Hash>] Array of team data
        def fetch_teams
          query = LinearCli::API::Queries::Analytics.list_teams
          result = @client.query(query)
          result.dig('teams', 'nodes') || []
        end

        # Fetch projects from the Linear API
        # @return [Array<Hash>] Array of project data
        def fetch_projects
          query = LinearCli::API::Queries::Analytics.list_projects
          result = @client.query(query)
          result.dig('projects', 'nodes') || []
        end

        # Fetch issues from the Linear API
        # @return [Array<Hash>] Array of issue data
        def fetch_issues
          query = LinearCli::API::Queries::Analytics.list_issues
          result = @client.query(query)
          result.dig('issues', 'nodes') || []
        end
      end
    end
  end
end
