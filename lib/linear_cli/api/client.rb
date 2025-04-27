require 'httparty'
require 'json'
require 'active_support/core_ext/string/inflections'
require_relative '../ui/logger'
require 'net/http'

module LinearCli
  module API
    # Linear API client
    class Client
      include HTTParty

      # Default API URL for Linear GraphQL endpoint
      API_URL = 'https://api.linear.app/graphql'.freeze

      # Default timeout values (in seconds)
      DEFAULT_TIMEOUT = 30
      DEFAULT_OPEN_TIMEOUT = 10

      # Default pagination values
      DEFAULT_PAGE_SIZE = 50
      DEFAULT_PAGE_LIMIT = 50

      # For test environment
      class << self
        attr_accessor :mock_response
      end

      # Initialize the client with an API key
      # @param api_key [String] Linear API key
      # @param api_url [String] Optional custom API URL
      # @param timeout [Integer] Request timeout in seconds
      # @param open_timeout [Integer] Connection open timeout in seconds
      def initialize(api_key = nil, api_url = nil, timeout = DEFAULT_TIMEOUT, open_timeout = DEFAULT_OPEN_TIMEOUT)
        @api_key = api_key || ENV.fetch('LINEAR_API_KEY', nil)
        @api_url = api_url || ENV['LINEAR_API_URL'] || API_URL
        @timeout = timeout
        @open_timeout = open_timeout

        raise 'Linear API key is required! Please set LINEAR_API_KEY in your .env file.' unless @api_key

        self.class.base_uri @api_url
      end

      # Execute a GraphQL query
      # @param query [String] GraphQL query
      # @param variables [Hash] GraphQL variables
      # @return [Hash] Response data
      def query(query, variables = {})
        # Use mock response in tests if provided
        return self.class.mock_response if defined?(RSpec) && self.class.mock_response

        # Check if this is a mutation and safe mode is enabled
        if LinearCli.safe_mode? && query.strip.start_with?('mutation')
          raise "Operation blocked: Safe mode is enabled. Mutations are not allowed in safe mode.\n" \
                'Use the --allow-mutations flag to perform this operation.'
        end

        # Create a progress bar for the operation
        operation_type = query.strip.start_with?('mutation') ? 'Mutation' : 'Query'
        operation_name = extract_operation_name(query)

        # Create a readable description for the progress bar
        description = if operation_name
                        "Executing #{operation_name}"
                      else
                        "Executing #{operation_type}"
                      end

        LinearCli::UI::Logger.info("#{description}...")

        # Make the actual request
        response = self.class.post(
          '',
          headers: headers,
          body: {
            query: query,
            variables: variables
          }.to_json,
          timeout: @timeout,
          open_timeout: @open_timeout
        )

        result = handle_response(response)

        # Log completion
        LinearCli::UI::Logger.info("#{description} completed.")

        result
      rescue StandardError => e
        # Log error
        LinearCli::UI::Logger.error("#{description} failed: #{e.message}")
        raise
      end

      # Fetch paginated data from the API
      # @param query [String] GraphQL query
      # @param variables [Hash] Initial GraphQL variables
      # @param options [Hash] Pagination options
      # @option options [Boolean] :fetch_all Whether to fetch all pages
      # @option options [Integer] :limit Maximum number of items to fetch
      # @option options [String] :nodes_path Path to nodes in the response (e.g., 'issues')
      # @option options [String] :page_info_path Path to pageInfo in the response (default: same as nodes_path)
      # @return [Array] Array of data nodes
      def fetch_paginated_data(query, variables, options = {})
        fetch_all = options[:fetch_all] || false
        limit = options[:limit] || DEFAULT_PAGE_LIMIT
        nodes_path = options[:nodes_path] || 'issues'
        page_info_path = options[:page_info_path] || nodes_path
        variables[:first] ||= DEFAULT_PAGE_SIZE

        # When fetch_all is true, ignore the limit
        limit = nil if fetch_all

        # Create a progress logger for the operation
        progress_message = "Fetching #{nodes_path.capitalize} data"

        all_items = []
        current_variables = variables.dup
        page_count = 0
        has_more_pages = true

        while has_more_pages
          page_count += 1

          LinearCli::UI::Logger.info("#{progress_message} (page #{page_count})")

          # Execute the query for this page
          response = self.class.post(
            '',
            headers: headers,
            body: {
              query: query,
              variables: current_variables
            }.to_json,
            timeout: @timeout,
            open_timeout: @open_timeout
          )

          body = JSON.parse(response.body)
          handle_error(body, response.code) if response.code != 200 || body['errors']
          result = body['data'] || {}

          # Extract nodes
          current_path = nodes_path.split('.')
          current_data = result
          current_path.each { |path| current_data = current_data[path] if current_data }

          # Extract items and pageInfo
          current_items = (current_data && current_data['nodes']) || []
          page_info_path_parts = page_info_path.split('.')
          page_info_data = result
          page_info_path_parts.each { |path| page_info_data = page_info_data[path] if page_info_data }
          page_info = page_info_data && page_info_data['pageInfo']

          # Add current items to the result
          all_items.concat(current_items)

          # Determine if we should fetch the next page
          has_next_page = page_info && page_info['hasNextPage']

          # Stop if we shouldn't fetch more pages
          break unless fetch_all

          # Stop if we've reached the limit
          break if limit && all_items.size >= limit

          # Stop if we've reached the last page
          break unless has_next_page

          # Get the cursor for the next page
          end_cursor = page_info['endCursor']
          current_variables[:after] = end_cursor

          # Continue to next page
          has_more_pages = true
        end

        # Complete the progress
        LinearCli::UI::Logger.info("Fetched #{all_items.size} items across #{page_count} pages") if page_count > 1
        LinearCli::UI::Logger.info("#{progress_message} completed.")

        all_items
      rescue StandardError => e
        # Log error
        LinearCli::UI::Logger.error("#{progress_message} failed: #{e.message}")
        raise
      end

      # Get team ID by name (case insensitive)
      # @param team_name [String] Name of the team
      # @return [String] Team ID
      # @raise [RuntimeError] If team is not found
      def get_team_id_by_name(team_name)
        LinearCli::UI::Logger.info("Finding team '#{team_name}'...")

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

        raise 'No teams found in your Linear workspace. Please create a team first.' if teams.empty?

        # Find team by case-insensitive name match
        team = teams.find { |t| t['name'].downcase == team_name.downcase }

        if team.nil?
          available_teams = teams.map { |t| "#{t['name']} (#{t['key']})" }.join(', ')
          raise "Team '#{team_name}' not found. Available teams: #{available_teams}"
        end

        team['id']
      end

      # @return [Boolean] True if the call was successful
      def check_url_connection
        uri = URI.parse(@api_url)
        response = Net::HTTP.get_response(uri)
        response.code.to_i < 400
      rescue StandardError
        false
      end

      # Send a GraphQL request to the Linear API and handle response
      # @param query [String] GraphQL query
      # @param variables [Hash] GraphQL variables
      # @return [Hash] Response data
      def request(query, variables = {})
        # Prepare headers with authentication
        headers = {
          'Content-Type' => 'application/json',
          'Authorization' => @api_key
        }

        # Log the request
        UI::Logger.info("Sending GraphQL request to #{@api_url}")

        # Make the request with timeout settings
        response = HTTParty.post(
          @api_url,
          body: { query: query, variables: variables }.to_json,
          headers: headers,
          timeout: @timeout,
          open_timeout: @open_timeout
        )

        # Parse and handle response
        handle_response(response)
      end

      private

      # Extract operation name from a GraphQL query or mutation
      # @param query [String] GraphQL query
      # @return [String, nil] The operation name or nil if not found
      def extract_operation_name(query)
        # Match query or mutation followed by a name
        match = query.match(/(?:query|mutation)\s+([A-Za-z0-9_]+)/)
        return match[1] if match

        # If no named operation found, check the first type definition
        # This is a fallback for cases where operations are unnamed
        field_match = query.match(/{\s*([a-zA-Z0-9_]+)/)
        field_match ? field_match[1] : nil
      end

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
        # For debugging in tests
        puts "DEBUG - Response status: #{response.code}" if defined?(RSpec)

        body = JSON.parse(response.body)

        # For debugging in tests
        puts "DEBUG - Response body data: #{body['data'].inspect}" if defined?(RSpec)
        puts "DEBUG - Response body errors: #{body['errors'].inspect}" if defined?(RSpec)

        # For all requests, validate normally
        handle_error(body, response.code) if response.code != 200 || body['errors']

        body['data'] || {}
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
          raise 'Authentication failed. Please check your Linear API key.'
        when 403
          raise "Access denied. Your API key doesn't have permission to perform this action."
        when 404
          raise 'Resource not found. Please check the ID or name you provided.'
        when 429
          raise 'Rate limit exceeded. Please try again in a few minutes.'
        else
          # Special handling for authentication errors even with non-401 status codes
          if messages.downcase.include?('authentication') || messages.downcase.include?('not authenticated')
            raise 'Authentication failed. Please check your Linear API key.'
          end

          raise "Linear API Error (#{code}): #{messages}"

        end
      end
    end
  end
end
