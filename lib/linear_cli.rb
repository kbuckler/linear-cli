require 'thor'
require 'httparty'
require 'dotenv'
require 'pastel'
require 'tty-table'
require 'tty-spinner'
require 'yaml'

# Load environment variables
Dotenv.load

# Require all files in the linear_cli directory
Dir[File.join(__dir__, 'linear_cli', '**', '*.rb')].sort.each { |file| require file }

module LinearCli
  # Main CLI application class
  class CLI < Thor
    # Set the application name for help text
    package_name 'linear'
    
    desc 'version', 'Display the Linear CLI version'
    def version
      puts "Linear CLI v#{LinearCli::VERSION}"
    end
    
    # Register all command classes
    register LinearCli::Commands::Issues, 'issues', 'issues [COMMAND]', 'Manage Linear issues'
    register LinearCli::Commands::Teams, 'teams', 'teams [COMMAND]', 'Manage Linear teams'
    register LinearCli::Commands::Projects, 'projects', 'projects [COMMAND]', 'Manage Linear projects'
    
    # Add common methods for all commands
    def self.exit_on_failure?
      true
    end
  end
end 