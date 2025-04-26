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
        
        raise 'Linear API key is required!' unless @api_key
        
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
        
        raise "Linear API Error (#{code}): #{messages}"
      end
    end
  end
end 