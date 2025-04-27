require 'httparty'
require 'json'
require 'active_support/core_ext/string/inflections'
require_relative '../ui/progress_bar'

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

        progress = LinearCli::UI::ProgressBar.create(description)

        # Start progress
        progress.advance(10)
        begin
          # Simulate network delay for better visual feedback
          progress.advance(30)

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

          # Almost done
          progress.advance(50)

          result = handle_response(response)

          # Complete the progress bar
          progress.finish

          result
        rescue StandardError => e
          # Complete the progress bar even on error
          progress.finish
          raise e
        end
      end

      # Fetch paginated data from the API
      # @param query [String] GraphQL query
      # @param variables [Hash] Initial GraphQL variables
      # @param options [Hash] Pagination options
      # @option options [Boolean] :fetch_all Whether to fetch all pages
      # @option options [Integer] :limit Maximum number of items to fetch
      # @option options [String] :nodes_path Path to nodes in the response (e.g., 'issues')
      # @option options [String] :page_info_path Path to pageInfo in the response (default: same as nodes_path)
      # @option options [String] :count_query [String] Optional query to get total count
      # @return [Array] Array of data nodes
      def fetch_paginated_data(query, variables, options = {})
        fetch_all = options[:fetch_all] || false
        limit = options[:limit] || 20
        nodes_path = options[:nodes_path] || 'issues'
        page_info_path = options[:page_info_path] || nodes_path
        options[:count_query]
        variables[:first] || 20

        # When fetch_all is true, ignore the limit
        limit = nil if fetch_all

        # Create a progress bar for the count operation if needed
        total_count = nil

        # For the first page, we'll create a simple progress bar
        progress_message = if total_count
                             "Fetching #{total_count} #{nodes_path.capitalize.pluralize(total_count)}"
                           else
                             "Fetching #{nodes_path.capitalize} data"
                           end

        progress = LinearCli::UI::ProgressBar.create(progress_message)

        all_items = []
        current_variables = variables.dup
        page_count = 0
        has_more_pages = true
        estimated_total_pages = 5 # Start with a reasonable estimate until we know better

        begin
          while has_more_pages
            page_count += 1

            # Update progress bar with current/estimated total pages
            if page_count == 1 || estimated_total_pages > page_count
              message = "[:bar] :percent Fetching #{nodes_path.capitalize} " \
                        "(page #{page_count} of #{estimated_total_pages})"
              progress.update(format: message)
            else
              progress.update(format: "[:bar] :percent Fetching #{nodes_path.capitalize} (page #{page_count})")
            end

            # Calculate progress based on what we know
            progress_per_page = 100.0 / [estimated_total_pages, page_count].max
            progress.advance(progress_per_page)

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

            # If we're on the first page and there's a next page, we can try to peek ahead
            # to get a better estimate of total pages
            # Update our estimate based on items received so far
            if page_count == 1 && has_next_page && fetch_all && current_items.size >= 10 && estimated_total_pages < 10
              estimated_total_pages = 10
              message = "[:bar] :percent Fetching #{nodes_path.capitalize} " \
                        "(page #{page_count} of #{estimated_total_pages}+)"
              progress.update(format: message)
            end

            # If we're approaching our estimated total, increase it
            if page_count >= estimated_total_pages - 1 && has_next_page
              estimated_total_pages *= 2
              message = "[:bar] :percent Fetching #{nodes_path.capitalize} " \
                        "(page #{page_count} of #{estimated_total_pages}+)"
              progress.update(format: message)
            end

            # If we're at the end, update with the exact total
            if !has_next_page && page_count > 1
              estimated_total_pages = page_count
              message = "[:bar] :percent Fetching #{nodes_path.capitalize} " \
                        "(page #{page_count} of #{estimated_total_pages})"
              progress.update(format: message)
            end

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
          progress.finish

          all_items
        rescue StandardError => e
          # Complete the progress bar even on error
          progress.finish
          raise e
        end
      end

      # Get team ID by name (case insensitive)
      # @param team_name [String] Name of the team
      # @return [String] Team ID
      # @raise [RuntimeError] If team is not found
      def get_team_id_by_name(team_name)
        progress = LinearCli::UI::ProgressBar.create("Finding team '#{team_name}'")
        progress.advance(30)

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

        begin
          result = query(query)
          teams = result['teams']['nodes']

          raise 'No teams found in your Linear workspace. Please create a team first.' if teams.empty?

          # Find team by case-insensitive name match
          team = teams.find { |t| t['name'].downcase == team_name.downcase }

          progress.advance(60)

          if team.nil?
            available_teams = teams.map { |t| "#{t['name']} (#{t['key']})" }.join(', ')
            raise "Team '#{team_name}' not found. Available teams: #{available_teams}"
          end

          progress.finish
          team['id']
        rescue StandardError => e
          progress.finish
          raise e
        end
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
