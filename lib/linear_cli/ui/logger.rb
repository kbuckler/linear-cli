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
        # @return [void]
        def info(message)
          return if in_test_environment?

          puts "#{timestamp} #{prefix('INFO', :blue)} #{message}"
        end

        # Log a warning message
        # @param message [String] The message to log
        # @return [void]
        def warn(message)
          return if in_test_environment?

          puts "#{timestamp} #{prefix('WARN', :yellow)} #{message}"
        end

        # Log a success message
        # @param message [String] The message to log
        # @return [void]
        def success(message)
          return if in_test_environment?

          puts "#{timestamp} #{prefix('SUCCESS', :green)} #{message}"
        end

        # Log an error message
        # @param message [String] The message to log
        # @return [void]
        def error(message)
          return if in_test_environment?

          puts "#{timestamp} #{prefix('ERROR', :red)} #{message}"
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
      end
    end
  end
end
