# frozen_string_literal: true

require 'thor'
require 'pastel'

module LinearCli
  # Main CLI application class
  class CLI < Thor
    # Set the application name for help text
    package_name 'linear'

    # Global options for all commands
    class_option :allow_mutations, type: :boolean, default: false,
                                   desc: 'Disable read-only safe mode ' \
                                         '(allows mutations)'

    def initialize(*args)
      super
      # Disable safe mode if allow_mutations flag is provided
      return unless options[:allow_mutations]

      LinearCli.safe_mode = !options[:allow_mutations]
    end

    desc 'version', 'Display the Linear CLI version'
    def version
      puts "Linear CLI v#{LinearCli::VERSION}"
    end

    # Register all command classes
    register LinearCli::Commands::Issues, 'issues', 'issues [COMMAND]',
             'Manage Linear issues'
    register LinearCli::Commands::Teams, 'teams', 'teams [COMMAND]',
             'Manage Linear teams'
    register LinearCli::Commands::Projects, 'projects', 'projects [COMMAND]',
             'Manage Linear projects'
    register LinearCli::Commands::Analytics, 'analytics', 'analytics [COMMAND]',
             'Analytics and reporting for Linear data'

    # Override help to provide a more comprehensive menu
    def help(command = nil, subcommand: true)
      if command.nil?
        display_main_help_menu
      else
        super
      end
    end

    # Add common methods for all commands
    def self.exit_on_failure?
      true
    end

    private

    # Display the main help menu with all available commands
    def display_main_help_menu
      pastel = Pastel.new
      print_header(pastel)

      # Display command sections
      display_global_commands(pastel)
      display_issue_commands(pastel)
      display_team_commands(pastel)
      display_project_commands(pastel)
      display_analytics_commands(pastel)

      print_footer
    end

    def print_header(pastel)
      puts pastel.bold('Linear CLI - Command Line Interface for Linear')
      puts pastel.cyan('A powerful tool for interacting with Linear from ' \
                       'your terminal')
      puts "\n#{pastel.dim('• Manage issues, teams, and projects')}"
      puts pastel.dim('• Run analytics and reporting on your Linear data')
      puts pastel.dim('• Supports structured output for scripting')
      puts "\n#{pastel.underline('Available Commands:')}"
    end

    def print_footer
      puts "\nFor more information on a specific command, run " \
           "'linear help COMMAND'"
      puts 'For detailed help on a subcommand, run ' \
           "'linear help COMMAND SUBCOMMAND'"
      puts "Example: 'linear help analytics report'"
    end

    def display_global_commands(pastel)
      puts "\n#{pastel.bold('Global Commands:')}"
      puts '  linear version                 # Display the Linear CLI version'
      cmd_help = 'Show help for all commands or a specific command'
      puts "  linear help [COMMAND]          # #{cmd_help}"

      mutations_help = 'Disable read-only safe mode to allow mutations'
      puts "  linear --allow-mutations <CMD> # #{mutations_help}"
    end

    def display_issue_commands(pastel)
      puts "\n#{pastel.bold('Issue Commands:')}"
      puts '  linear issues list           # List Linear issues'
      pagination_help = 'List all issues without pagination limits'
      puts "  linear issues list --all     # #{pagination_help}"
      puts '  linear issues view ID        # View details of a specific issue'
      puts '  linear issues create         # Create a new issue'
      puts '  linear issues update ID      # Update an existing issue'
      puts '  linear issues comment ID     # Add a comment to an issue'
    end

    def display_team_commands(pastel)
      puts "\n#{pastel.bold('Team Commands:')}"
      puts '  linear teams list            # List Linear teams'
      puts '  linear teams view ID         # View details of a specific team'
    end

    def display_project_commands(pastel)
      puts "\n#{pastel.bold('Project Commands:')}"
      puts '  linear projects list         # List Linear projects'
      project_help = 'View details of a specific project'
      puts "  linear projects view ID      # #{project_help}"
    end

    def display_analytics_commands(pastel)
      puts "\n#{pastel.bold('Analytics & Reporting Commands:')}"
      report_help = 'Generate comprehensive workspace report'
      puts "  linear analytics report      # #{report_help}"
    end
  end
end
