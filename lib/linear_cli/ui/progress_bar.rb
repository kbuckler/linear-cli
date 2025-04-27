require 'tty-progressbar'

module LinearCli
  module UI
    # Provides progress bar functionality for network operations
    module ProgressBar
      # Creates a new progress bar for a network operation
      # @param operation [String] Description of the operation
      # @param options [Hash] Options for the progress bar
      # @option options [Integer] :total Total steps for the progress bar
      # @option options [Integer] :width Width of the progress bar
      # @return [TTY::ProgressBar] The progress bar instance
      def self.create(operation, options = {})
        return NullProgressBar.new unless $stdout.tty?
        return NullProgressBar.new if ENV['RACK_ENV'] == 'test' || ENV['RAILS_ENV'] == 'test'

        # Set default options
        total = options[:total] || 100
        width = options[:width] || 40

        # Format operation text for better display
        operation_text = format_operation(operation)

        # Create the progress bar with the formatted operation text
        TTY::ProgressBar.new(
          "[:bar] :percent #{operation_text}",
          total: total,
          width: width,
          complete: '=',
          incomplete: ' '
        )
      end

      # Format operation text for better readability
      # @param operation [String] Operation description
      # @return [String] Formatted operation description
      def self.format_operation(operation)
        # Ensure proper capitalization and spacing
        operation = operation.to_s.strip
        operation = operation.capitalize unless operation.match?(/[A-Z]/)
        operation
      end

      # No-op progress bar for non-TTY environments
      class NullProgressBar
        def initialize
          # No initialization needed
        end

        def advance(*)
          # No-op
        end

        def finish
          # No-op
        end

        def update(*)
          # No-op
        end
      end
    end
  end
end
