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
    
    # Override help to provide a more comprehensive menu
    def help(command = nil, subcommand = true)
      if command.nil?
        pastel = Pastel.new
        puts pastel.bold("Linear CLI - Command Line Interface for Linear")
        puts "\n#{pastel.underline('Available Commands:')}"
        
        puts "\n#{pastel.bold('Global Commands:')}"
        puts "  linear version               # Display the Linear CLI version"
        puts "  linear help [COMMAND]        # Show help for all commands or a specific command"
        
        puts "\n#{pastel.bold('Issue Commands:')}"
        puts "  linear issues list           # List Linear issues"
        puts "  linear issues list --detail  # List issues with detailed attributes"
        puts "  linear issues view ID        # View details of a specific issue"
        puts "  linear issues create         # Create a new issue"
        puts "  linear issues update ID      # Update an existing issue"
        puts "  linear issues comment ID     # Add a comment to an issue"
        
        puts "\n#{pastel.bold('Team Commands:')}"
        puts "  linear teams list            # List Linear teams"
        puts "  linear teams view ID         # View details of a specific team"
        
        puts "\n#{pastel.bold('Project Commands:')}"
        puts "  linear projects list         # List Linear projects"
        puts "  linear projects view ID      # View details of a specific project"
        
        puts "\nFor more information on a specific command, run 'linear help COMMAND'"
      else
        super
      end
    end
    
    # Add common methods for all commands
    def self.exit_on_failure?
      true
    end
  end
end 