module LinearCli
  module UI
    # Simple logger for Linear CLI operations
    class Logger
      class << self
        # Log an informational message
        # @param message [String] The message to log
        def info(message)
          puts format_message(message)
        end

        # Log an error message
        # @param message [String] The error message to log
        def error(message)
          puts format_message(message, type: 'ERROR')
        end

        private

        # Format a log message with timestamp
        # @param message [String] The message to format
        # @param type [String] Optional message type (e.g., 'ERROR')
        # @return [String] Formatted message
        def format_message(message, type: nil)
          timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
          prefix = type ? "[#{type}] " : ''
          "#{timestamp} #{prefix}#{message}"
        end
      end
    end
  end
end
