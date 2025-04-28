# frozen_string_literal: true

module LinearCli
  module Validators
    # Input validation module to sanitize and validate user input
    # Provides methods to validate issue IDs, team names, email addresses, etc.
    module InputValidator
      # Regular expression for issue identifiers (e.g., ENG-123)
      ISSUE_ID_REGEX = /^[A-Za-z]+-\d+$/.freeze

      # Regular expression for valid email addresses
      EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i.freeze

      # Validate issue identifier format
      # @param id [String] Issue identifier
      # @return [Boolean] True if valid, raises error if invalid
      # @raise [ArgumentError] If id format is invalid
      def self.validate_issue_id(id)
        unless id.match?(ISSUE_ID_REGEX)
          raise ArgumentError,
                "Invalid issue ID format: '#{id}'. " \
                "Expected format like 'ABC-123'."
        end

        true
      end

      # Validate priority value
      # @param priority [Integer] Priority value
      # @return [Boolean] True if valid, raises error if invalid
      # @raise [ArgumentError] If priority is out of range
      def self.validate_priority(priority)
        priority = priority.to_i
        unless (0..4).include?(priority)
          raise ArgumentError,
                "Invalid priority value: #{priority}. " \
                'Expected a number between 0-4.'
        end

        true
      end

      # Sanitize string input to prevent injection
      # @param input [String] Input string
      # @return [String] Sanitized string
      def self.sanitize_string(input)
        return nil if input.nil?

        # Remove any control characters and trim whitespace
        input.to_s.gsub(/[\x00-\x1F\x7F]/, '').strip
      end

      # Validate and sanitize team name
      # @param team_name [String] Team name
      # @return [String] Sanitized team name
      # @raise [ArgumentError] If team name is blank
      def self.validate_team_name(team_name)
        sanitized = sanitize_string(team_name)
        raise ArgumentError, 'Team name cannot be blank.' if sanitized.empty?

        sanitized
      end

      # Validate and sanitize title
      # @param title [String] Issue title
      # @return [String] Sanitized title
      # @raise [ArgumentError] If title is blank
      def self.validate_title(title)
        sanitized = sanitize_string(title)
        raise ArgumentError, 'Title cannot be blank.' if sanitized.empty?

        sanitized
      end

      # Validate and sanitize description
      # @param description [String] Issue description
      # @return [String] Sanitized description
      def self.validate_description(description)
        return nil if description.nil?

        sanitize_string(description)
      end

      # Validate and sanitize comment body
      # @param body [String] Comment body
      # @return [String] Sanitized body
      # @raise [ArgumentError] If body is blank
      def self.validate_comment_body(body)
        sanitized = sanitize_string(body)
        raise ArgumentError, 'Comment body cannot be blank.' if sanitized.empty?

        sanitized
      end

      # Validate email format
      # @param email [String] Email address
      # @return [Boolean] True if valid, raises error if invalid
      # @raise [ArgumentError] If email format is invalid
      def self.validate_email(email)
        unless email.match?(EMAIL_REGEX)
          raise ArgumentError,
                "Invalid email format: '#{email}'."
        end

        true
      end

      # Validate limit parameter
      # @param limit [Integer] Limit value
      # @return [Integer] Validated limit
      # @raise [ArgumentError] If limit is invalid
      def self.validate_limit(limit)
        limit = limit.to_i
        if limit <= 0
          raise ArgumentError,
                "Limit must be a positive number, got: #{limit}"
        end

        # Cap at a reasonable maximum to prevent abuse
        [limit, 100].min
      end
    end
  end
end
