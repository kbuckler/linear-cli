require 'httparty'
require 'json'

module LinearCli
  module API
    # Linear API client
    class Client
      include HTTParty
      
      # Default API URL for Linear GraphQL endpoint
      API_URL = 'https://api.linear.app/graphql'.freeze
      
      # Initialize the client with an API key
      # @param api_key [String] Linear API key
      # @param api_url [String] Optional custom API URL
      def initialize(api_key = nil, api_url = nil)
        @api_key = api_key || ENV['LINEAR_API_KEY']
        @api_url = api_url || ENV['LINEAR_API_URL'] || API_URL
        
        raise 'Linear API key is required! Please set LINEAR_API_KEY in your .env file.' unless @api_key
        
        self.class.base_uri @api_url
      end
      
      # Execute a GraphQL query
      # @param query [String] GraphQL query
      # @param variables [Hash] GraphQL variables
      # @return [Hash] Response data
      def query(query, variables = {})
        response = self.class.post(
          '',
          headers: headers,
          body: {
            query: query,
            variables: variables
          }.to_json
        )
        
        handle_response(response)
      end

      # Get team ID by name (case insensitive)
      # @param team_name [String] Name of the team
      # @return [String] Team ID
      # @raise [RuntimeError] If team is not found
      def get_team_id_by_name(team_name)
        query = <<~GRAPHQL
          query Teams {
            teams {
              nodes {
                id
                name
                key
              }
            }
          }
        GRAPHQL

        result = query(query)
        teams = result['teams']['nodes']

        if teams.empty?
          raise "No teams found in your Linear workspace. Please create a team first."
        end

        # Find team by case-insensitive name match
        team = teams.find { |t| t['name'].downcase == team_name.downcase }
        
        if team.nil?
          available_teams = teams.map { |t| "#{t['name']} (#{t['key']})" }.join(', ')
          raise "Team '#{team_name}' not found. Available teams: #{available_teams}"
        end

        team['id']
      end
      
      private
      
      # Headers for API requests
      # @return [Hash] Headers hash
      def headers
        {
          'Content-Type' => 'application/json',
          'Authorization' => @api_key
        }
      end
      
      # Handle API response and errors
      # @param response [HTTParty::Response] API response
      # @return [Hash] Parsed response
      # @raise [RuntimeError] If API returns an error
      def handle_response(response)
        body = JSON.parse(response.body)
        
        if response.code != 200 || body['errors']
          handle_error(body, response.code)
        end
        
        body['data']
      end
      
      # Handle API errors
      # @param body [Hash] Response body
      # @param code [Integer] HTTP status code
      # @raise [RuntimeError] With error message
      def handle_error(body, code)
        errors = body['errors'] || []
        messages = errors.map { |e| e['message'] }.join(', ')
        
        case code
        when 401
          raise "Authentication failed. Please check your Linear API key."
        when 403
          raise "Access denied. Your API key doesn't have permission to perform this action."
        when 404
          raise "Resource not found. Please check the ID or name you provided."
        when 429
          raise "Rate limit exceeded. Please try again in a few minutes."
        else
          raise "Linear API Error (#{code}): #{messages}"
        end
      end
    end
  end
end 