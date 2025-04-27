# Technology Decisions

## Language and Framework
- **Ruby**: We will use Ruby for developing the command-line tool due to its excellent support for creating CLIs, readable syntax, and robust ecosystem of gems.
- **Thor**: We will use the Thor gem for building the command-line interface, as it provides a clean DSL for defining commands and options.

## API Integration
- **Linear API**: We will use Linear's REST API with the GraphQL endpoint for interacting with Linear data.
- **HTTP Client**: We will use the `httparty` gem for making API requests to Linear.

## Authentication
- **API Key**: Authentication will be handled using Linear API keys stored in environment variables or a configuration file.
- **Configuration**: We will use a YAML configuration file for storing non-sensitive settings and dotenv for environment variables.

## Project Structure
- **Command-Line Interface**: The tool will be structured as a CLI with subcommands for different operations.
- **Models**: Ruby classes will represent Linear entities (issues, projects, teams, etc.).
- **Services**: Separate service classes will handle API communication.

## Testing
- **RSpec**: We will use RSpec for unit and integration testing.
- **VCR**: For recording and replaying HTTP interactions in tests.
- **API Mocking**: Use a simple mock response approach instead of WebMock stubs for API client testing
  - **Context**: WebMock and VCR can lead to complexity in maintaining request/response pairs
  - **Implementation**: Added a class-level `mock_response` attribute to the API client that tests can set
  - **Consequences**:
    - Simplified test setup with clearer intentions
    - Decoupled tests from HTTP implementation details
    - Easier maintenance and less brittle tests
    - VCR can still be used for integration tests when needed

## Dependency Management
- **Bundler**: We will use Bundler for managing gem dependencies.

## Terminal Output in Tests

- **Decision**: Use simplified text output instead of TTY::Table rendering in test environments
- **Context**: TTY::Table requires terminal capabilities that aren't available in test environments (StringIO)
- **Implementation**: Check for test environment (`RACK_ENV` or `RAILS_ENV`) and use basic string formatting
- **Consequences**: 
  - Tests can run without terminal-related errors
  - Test output is still readable and verifiable
  - Production environment maintains rich terminal formatting 

## Security Practices

- **Decision**: Implement input validation and sanitization for all user-provided data
- **Context**: User inputs can contain malicious data or unintended characters that could lead to security issues
- **Implementation**: 
  - Created a dedicated InputValidator module for validating and sanitizing all user inputs
  - Added validation for issue IDs, email addresses, priorities, and other input types
  - Implemented sanitization to remove control characters and trim whitespace
  - Added bounds checking for numeric inputs to prevent abuse
- **Consequences**:
  - Reduced risk of injection attacks against the Linear API
  - Better error handling for malformed inputs
  - Improved reliability of the CLI tool
  - Enhanced security when processing user-provided data 

## Analytics Module Architecture

- **Decision**: Create a dedicated analytics module with separate reporting and display components
- **Context**: The project needed strong reporting capabilities with a clean separation of concerns
- **Implementation**:
  - Created `Analytics::Reporting` module for pure data processing and analytics calculations
  - Created `Analytics::Display` module for formatting and presenting results
  - Used functional programming approach with stateless methods for better testability
- **Consequences**:
  - Improved code organization with clear separation of concerns
  - Better testability with isolated components
  - More maintainable reporting system
  - Easier to extend with new analytics features in the future
  - Consistent display formatting across command output 

## Software Capitalization Analysis

- **Decision**: Add software capitalization analysis to the analytics module
- **Context**: Organizations need to track which software development efforts are capitalized vs. expensed for financial reporting
- **Implementation**:
  - Added `calculate_capitalization_metrics` method to the Reporting module
  - Created display methods for capitalization metrics in the Display module
  - Used label-based identification for capitalized issues (e.g., 'capitalization', 'capex', 'fixed asset')
  - Implemented team-level breakdown of capitalization rates
- **Consequences**:
  - Enables financial reporting on development efforts
  - Provides visibility into capitalization rates by team
  - Helps track capitalized vs. non-capitalized work
  - Simplifies financial auditing and compliance reporting 

## Project-Based Capitalization Analysis

- **Decision**: Change capitalization analysis to be per-project instead of per-issue
- **Context**: Capitalization status is typically determined at the project level in organizations, not at the individual issue level
- **Implementation**:
  - Updated `calculate_capitalization_metrics` to primarily check project labels for capitalization status
  - Modified GraphQL queries to include project labels information
  - Maintained backward compatibility by continuing to check issue labels when project labels aren't available
  - Added appropriate documentation in display output
- **Consequences**:
  - More accurately models real-world financial tracking practices
  - Streamlines capitalization labeling (apply once at project level instead of on every issue)
  - Reduces inconsistencies in capitalization reporting
  - Maintains backward compatibility with existing issue-level labels 

## Removal of Issue-Level Capitalization Support

- **Decision**: Remove backward compatibility for issue-level capitalization
- **Context**: After transitioning to project-based capitalization tracking, maintaining backward compatibility with issue-level capitalization increased code complexity
- **Implementation**:
  - Removed code that checks for capitalization labels on individual issues
  - Updated display text to indicate capitalization is determined only by project labels
  - Modified tests to reflect the exclusive use of project-level capitalization
- **Consequences**:
  - Simplified code with a single source of truth for capitalization status
  - Clearer mental model for users (capitalization is only a project property)
  - Better alignment with financial tracking practices in organizations
  - Note: Existing issues with capitalization labels but no capitalized project will no longer be counted as capitalized 

## Dedicated Analytics Module

- **Decision**: Move analytics and reporting functionality to a dedicated command class
- **Context**: Analytics and reporting are core features that needed their own command focus
- **Implementation**:
  - Created a `Commands::Analytics` class with focused reporting methods
  - Added a dedicated `capitalization` command for targeted capitalization reporting
  - Added comprehensive reporting features
- **Consequences**:
  - More intuitive CLI structure for users
  - Easier to extend reporting capabilities in the future
  - Focused approach to analytics functionality
  - Better aligned with the principle of having a single, obvious way to accomplish a task

## Enhanced Capitalization Reporting

- **Decision**: Enhance the capitalization reporting to track projects and engineer workload
- **Context**: Organizations need more detailed analysis of capitalization metrics to track financial data accurately
- **Implementation**:
  - Added list of specific capitalized projects to the report output
  - Added engineer workload metrics showing time allocation on capitalized vs. non-capitalized work
  - Added time-period filtering to allow monthly/quarterly/yearly analysis
  - Enhanced GraphQL queries to include additional data needed for time and workload calculations
- **Consequences**:
  - More comprehensive capitalization tracking for financial reporting
  - Better ability to analyze engineer time allocation across capitalized projects
  - Ability to generate time-based reports for different financial periods
  - Improved tracking of project-based capitalization metrics

## Enhanced Terminal Output for Analytics

- **Decision**: Use dedicated terminal libraries for improved analytics display
- **Context**: The analytics module needed more advanced output formatting including tables, colors, and structured display
- **Implementation**:
  - Added the `terminal-table` gem for structured tabular output
  - Added the `colorize` gem for colorizing terminal output
  - Maintained compatibility with TTY libraries used elsewhere in the application
  - Improved formatting for percentage values with color-coding based on thresholds
- **Consequences**:
  - Enhanced readability of analytics output
  - Better visual distinction between different types of data
  - Improved user experience with color-coded metrics
  - More professional presentation of capitalization metrics 

## Engineer Workload Analysis

- **Decision**: Add engineer workload analysis showing project contributions over time
- **Context**: Organizations need to track how engineers are distributing their time across projects for better resource planning
- **Implementation**:
  - Created a dedicated `engineer_workload` command in the Analytics module
  - Designed a data structure that organizes by team → project → engineer
  - Calculated contribution percentages based on story point estimates
  - Implemented monthly view going back 6 months for trend analysis
  - Used Terminal::Table for clear tabular presentation
- **Consequences**:
  - Better visibility into how engineers distribute their work across projects
  - Historical trend data to analyze resource allocation changes
  - Ability to identify engineers' focus areas and project contributions
  - Enhanced decision-making for project staffing and resource allocation
  - Improved tracking of engineer productivity and project investment 

## Removal of Generator Command and Data Generator Client Code

- **Decision**: Remove the generator command and associated data generator client code
- **Context**: The data generator module has been superseded by more focused analytics tooling and is no longer needed as a separate command
- **Implementation**:
  - Removed `Commands::Generator` class
  - Removed `API::DataGenerator` class
  - Removed `API::Queries::Generator` module
  - Created new `API::Queries::Analytics` module to support the analytics command
  - Updated CLI registration and help text to remove generator command references
- **Consequences**:
  - Simplified codebase with fewer commands to maintain
  - More focused command structure (analytics for reporting, no separate data generation)
  - Commands for generating test data have been removed
  - Analytics module now handles all reporting functionality with its own query definitions 

## Read-Only Safe Mode

- **Decision**: Add a read-only safe mode to prevent accidental mutations
- **Context**: Users sometimes need to ensure they won't accidentally modify data when exploring or running reports
- **Implementation**:
  - Added a global `--safe-mode` flag to the CLI
  - Implemented detection of mutation operations in the API client
  - Added immediate termination with clear error messages when mutations are attempted in safe mode
  - Safe mode is disabled by default to maintain backward compatibility
- **Consequences**:
  - Provides a safety mechanism to prevent accidental data modification
  - Allows users to confidently run the CLI for reporting and exploration without risk
  - Simplifies creation of read-only integration scripts using the CLI
  - Helps prevent accidental changes in production environments
  - Maintains backward compatibility with existing workflow by being off by default

## Safe Mode Default Change

- **Decision**: Change safe mode to be enabled by default
- **Context**: After initial implementation of safe mode, we decided that a safer approach is to require explicit authorization for mutations
- **Implementation**:
  - Changed `--safe-mode` flag to `--allow-mutations` with reversed logic
  - Made safe mode enabled by default
  - Updated error messages to reflect the new flag for disabling safe mode
  - Updated tests and documentation to reflect this change
- **Consequences**:
  - Improved safety by requiring explicit consent for data-changing operations
  - Reduces risk of accidental mutations when running CLI commands
  - Better aligns with the principle of "safe by default"
  - Note: This is a breaking change from previous behavior where mutations were allowed by default 

## Table Rendering Orientation

- **Decision**: Ensure all TTY::Table renderings maintain horizontal orientation
- **Context**: Tables were exceeding the set width, causing errors with message "the table size exceeds the currently set width"
- **Implementation**:
  - Added `resize: false` to all TTY::Table render calls
  - Removed explicit width constraints but kept column width specifications 
  - Added consistent column width specifications to all tables for better display
  - Maintained existing padding for consistent visual appearance
- **Consequences**:
  - Tables will always display in horizontal orientation
  - Column sizes will adapt to content while maintaining minimum widths
  - Consistent display across all table rendering in the application
  - Improved user experience with more readable tabular data
  - More predictable table layouts with standardized column widths 

## Simplified Issue Table Display

- **Decision**: Simplify issue table display to always show the detailed view
- **Context**: The application previously offered both a standard and detailed view for issues, adding complexity with minimal benefit
- **Implementation**:
  - Removed the `--detail` flag from the issues list command
  - Always display the comprehensive view with all issue attributes
  - Kept the appropriate column widths for optimal display
  - Maintained test environment handling for non-TTY output
- **Consequences**:
  - Simplified codebase by removing conditional rendering logic
  - More consistent user experience with a single, information-rich view
  - All important issue attributes are always visible
  - Better contextual information for issue triage and management
  - Reduced cognitive load by removing unnecessary command options 

## Centralized TTY Table Rendering

- **Decision**: Create a centralized table rendering module to manage all TTY table rendering with consistent styling
- **Context**: Table rendering logic was scattered across multiple files with inconsistent styling and duplicated test environment handling
- **Implementation**:
  - Created `LinearCli::UI::TableRenderer` module with standardized rendering methods
  - Consolidated test environment detection logic
  - Provided consistent styling defaults while allowing customization
  - Simplified API for both simple and complex table rendering needs
- **Consequences**:
  - Improved code maintainability with single source of truth for table styling
  - Consistent user experience across all tabular data displays
  - Easier to update or modify table styling globally
  - Simplified test environment handling with automatic format switching 