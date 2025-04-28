# frozen_string_literal: true

module LinearCli
  module UI
    # Simple logger with colored output for better user experience
    # Provides standard methods for info, warning, success and error messages
    module Logger
      class << self
        # Check if running in test environment
        # @return [Boolean] True if running in test environment
        def in_test_environment?
          defined?(RSpec) || ENV['RACK_ENV'] == 'test' ||
            ENV['RAILS_ENV'] == 'test' || !$stdout.tty?
        end

        # Log an informational message
        # @param message [String] The message to log
        # @param context [Hash] Optional context information to include
        # @return [void]
        def info(message, context = {})
          return if in_test_environment?

          log_message('INFO', message, :blue, context)
        end

        # Log a warning message
        # @param message [String] The message to log
        # @param context [Hash] Optional context information to include
        # @return [void]
        def warn(message, context = {})
          return if in_test_environment?

          log_message('WARN', message, :yellow, context)
        end

        # Log a success message
        # @param message [String] The message to log
        # @param context [Hash] Optional context information to include
        # @return [void]
        def success(message, context = {})
          return if in_test_environment?

          log_message('SUCCESS', message, :green, context)
        end

        # Log an error message
        # @param message [String] The message to log
        # @param context [Hash] Optional context information to include
        # @return [void]
        def error(message, context = {})
          return if in_test_environment?

          log_message('ERROR', message, :red, context)
        end

        # Log a debug message (only shown when DEBUG=true)
        # @param message [String] The message to log
        # @param context [Hash] Optional context information to include
        # @return [void]
        def debug(message, context = {})
          return if in_test_environment?
          return unless ENV['LINEAR_CLI_DEBUG'] == 'true'

          log_message('DEBUG', message, :magenta, context)
        end

        private

        # Get current timestamp in format [HH:MM:SS]
        # @return [String] Formatted timestamp
        def timestamp
          time = Time.now
          "[#{time.strftime('%H:%M:%S')}]"
        end

        # Format a prefix with optional color
        # @param text [String] The prefix text
        # @param color [Symbol] The color to use
        # @return [String] Formatted prefix
        def prefix(text, color)
          text = "[#{text}]".ljust(10)
          colorize(text, color)
        end

        # Add color to text if terminal supports it
        # @param text [String] The text to colorize
        # @param color [Symbol] The color to use
        # @return [String] Colorized text
        def colorize(text, color)
          return text unless defined?(Colorize) && $stdout.tty?

          text.colorize(color)
        end

        # Log a message with context information
        # @param level [String] Log level
        # @param message [String] The message to log
        # @param color [Symbol] The color to use
        # @param context [Hash] Context information to include
        # @return [void]
        def log_message(level, message, color, context = {})
          base_message = "#{timestamp} #{prefix(level, color)} #{message}"

          if context && !context.empty?
            context_str = context.map { |k, v| "#{k}=#{v}" }.join(', ')
            puts "#{base_message} (#{context_str})"
          else
            puts base_message
          end
        end
      end
    end
  end
end
