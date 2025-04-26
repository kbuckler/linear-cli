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

## Data Generator Module

- **Decision**: Create a dedicated data generator module for populating Linear instances and enabling complex reporting
- **Context**: There is a need to efficiently populate Linear instances with test data for analysis and reporting
- **Implementation**:
  - Created a DataGenerator class to handle bulk creation of teams, projects, and issues
  - Added support for flexible configuration of data generation (number of teams, projects, issues, etc.)
  - Implemented a reporting command to analyze and visualize the Linear instance data
  - Provided both tabular and JSON output formats for data analysis
- **Consequences**:
  - Easier testing and development of Linear workflows with populated data
  - Enabled data-driven insights through the reporting module
  - Simplified setup of demo environments for presentations and testing
  - Enhanced CLI capabilities for complex reporting and analysis tasks 

## Analytics Module Architecture

- **Decision**: Create a dedicated analytics module with separate reporting and display components
- **Context**: The data generator module needed reporting capabilities with a clean separation of concerns
- **Implementation**:
  - Created `Analytics::Reporting` module for pure data processing and analytics calculations
  - Created `Analytics::Display` module for formatting and presenting results
  - Moved all analytics-related code from the generator command into these modules
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
- **Context**: Previously, reporting functionality was mixed with data generation in the generator command, but these are conceptually separate concerns
- **Implementation**:
  - Created a new `Commands::Analytics` class with focused reporting methods
  - Added a dedicated `capitalization` command for targeted capitalization reporting
  - Moved common reporting code from generator to the analytics command
  - Added deprecation notice to the old `generator dump` command
  - Added a `dump` command to analytics as an alias for `report` to maintain backward compatibility
- **Consequences**:
  - Better separation of concerns between data generation and reporting
  - More intuitive CLI structure for users
  - Easier to extend reporting capabilities in the future
  - Deprecation approach ensures backward compatibility during transition
  - Full compatibility with existing scripts that used `generator dump` is maintained via the alias

## Removal of Backward Compatibility for Dump Command

- **Decision**: Remove the backward compatibility dump command from analytics module
- **Context**: After introducing the separate analytics command module with a backward compatibility alias for the old generator dump command, we decided to simplify the API surface
- **Implementation**:
  - Removed the `dump` command from the analytics module
  - Updated the deprecation message in generator's dump command to point only to `analytics report`
  - Removed mentions of the dump command from the help text
- **Consequences**:
  - Cleaner, more focused command structure
  - Simplified mental model for users (report vs capitalization rather than dump vs report)
  - Minor breaking change for any scripts using the temporary `analytics dump` command
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

## Enhanced Test Data Generator for Workload Analysis

- **Decision**: Enhance the data generator to create realistic test data for engineer workload reporting
- **Context**: The engineer workload report requires historical data with story points and consistent patterns to properly test and demonstrate the feature
- **Implementation**:
  - Updated the generator to create issues with story point estimates
  - Added time-based generation spanning multiple months (up to 6 months of history)
  - Created consistent distribution patterns of engineers across projects
  - Generated varying story point values to simulate different issue complexities
  - Added command-line options to control the volume and characteristics of generated data
- **Consequences**:
  - Easier testing and demonstration of the engineer workload report
  - More realistic data that mimics real-world work patterns
  - Better ability to spot trends and patterns in the generated reports
  - Improved ability to validate the workload analysis functionality
  - More comprehensive test coverage for the analytics module 

## Lifecycle-Aware Test Data Generation

- **Decision**: Enhance the test data generator to simulate realistic issue lifecycle states
- **Context**: Testing time-based analytics requires issues in various states (backlog, in progress, completed) with appropriate timestamps
- **Implementation**:
  - Added support for marking issues with appropriate workflow states (backlog, in-progress, completed)
  - Created a realistic distribution where older issues are more likely to be completed
  - Set appropriate workflow states based on issue status (backlog, in progress, done)
  - Generated issues across multiple months to simulate project progress over time
  - Added status information to issue descriptions for easier debugging and verification
- **Consequences**:
  - More realistic simulation of actual project activity over time
  - Better testing for analytics that depend on issue completion status
  - Improved ability to validate time-based reports and burndown charts
  - More accurate representation of development team velocity over time
  - Enhanced usefulness of generated test data for demonstrations 
- **Implementation Notes**:
  - Direct setting of `completedAt` and `startedAt` dates is not supported by the Linear API
  - Instead, we set the issue to a "completed" workflow state which implicitly marks it as completed
  - Status information is added to the issue description to maintain traceability 

## Enhanced Test Data Generator with Actual User Assignments

- **Decision**: Modify the test data generator to assign issues to actual users on the Linear account
- **Context**: Previously, the generator created issues with fictional engineer assignments, which didn't allow for realistic testing of assignment-based reports and filters
- **Implementation**:
  - Added ability to assign issues to real users from the teams
  - Implemented a configurable percentage (default 70%) of issues to assign to real users
  - Added fallback to fictional engineers when no real users are available
  - Maintained backward compatibility with fictional engineer assignments
  - Added clear indication in issue descriptions of whether they are assigned to real or fictional users
- **Consequences**:
  - More realistic testing with actual user accounts
  - Ability to test user-specific filters and reports with generated data
  - Better simulation of real-world workflows
  - Improved testing of assignment-based analytics
  - Options to control the percentage of real vs. fictional assignments for flexibility 