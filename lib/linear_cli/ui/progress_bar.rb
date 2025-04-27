require 'tty-progressbar'

module LinearCli
  module UI
    # Provides progress bar functionality for network operations
    module ProgressBar
      # Creates a new progress bar for a network operation
      # @param operation [String] Description of the operation
      # @return [TTY::ProgressBar] The progress bar instance
      def self.create(operation)
        return NullProgressBar.new unless $stdout.tty?
        return NullProgressBar.new if ENV['RACK_ENV'] == 'test' || ENV['RAILS_ENV'] == 'test'

        TTY::ProgressBar.new(
          "[:bar] :percent #{operation}",
          total: 100,
          width: 40,
          complete: '=',
          incomplete: ' '
        )
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
