# frozen_string_literal: true

require 'thor'
require 'httparty'
require 'dotenv'
require 'pastel'
require 'tty-table'
require 'tty-spinner'
require 'yaml'

# Load environment variables
Dotenv.load

# First, load version and common modules
require_relative 'linear_cli/version'

# Then, load command classes
Dir[File.join(__dir__, 'linear_cli', 'commands', '**',
              '*.rb')].sort.each do |file|
  require file
end

# Now load the CLI class
require_relative 'linear_cli/cli'

# Finally, load all remaining files
Dir[File.join(__dir__, 'linear_cli', '{api,ui,services,analytics,validators}',
              '**', '*.rb')].sort.each do |file|
  require file
end

# Linear CLI module - provides command-line interface to Linear app
# Main functionality includes issue, team, and project management
# along with analytics and reporting tools
module LinearCli
  # Global configuration for read-only safe mode
  @safe_mode = true

  # Getter for safe mode
  def self.safe_mode?
    @safe_mode
  end

  # Setter for safe mode
  def self.safe_mode=(value)
    @safe_mode = value
  end
end
