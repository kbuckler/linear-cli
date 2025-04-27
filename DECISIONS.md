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

## Simplified TTY Table Rendering

- **Decision**: Simplify TTY table rendering to avoid width constraint issues
- **Context**: The TTY::Table width handling was causing errors when rendering tables with the message "undefined method '<=' for an instance of Array"
- **Implementation**:
  - Removed explicit width array setting in the TableRenderer module
  - Used default TTY::Table width handling which better adapts to content
  - Fixed GraphQL query structure for team members to match Linear API schema
- **Consequences**:
  - More robust table rendering with fewer errors
  - Tables automatically adapt to content size
  - Better compatibility with the Linear API's expected GraphQL structure
  - Simplified renderer code with fewer potential points of failure 

## GraphQL Pagination Support

- **Decision**: Implement cursor-based pagination to fetch all issues when requested
- **Context**: Users need to be able to view and analyze the full set of issues, not just a limited batch
- **Implementation**:
  - Added an `--all` flag to the issues list command to fetch all issues
  - Implemented cursor-based pagination using GraphQL's pageInfo
  - Used a while loop to fetch pages until all issues are retrieved or until the requested limit is reached
  - Preserved existing behavior with limits when not fetching all issues
- **Consequences**:
  - Users can now see all issues at once without arbitrary limits
  - Better support for reporting and analysis use cases
  - Improved user experience when needing to browse all issues
  - Potential for slower performance with very large issue sets 

## Pagination Logic Refactoring

- **Decision**: Extract pagination logic into a reusable method in the API client
- **Context**: Pagination logic was duplicated in multiple command classes
- **Implementation**:
  - Added `fetch_paginated_data` method to the `LinearCli::API::Client` class
  - Method accepts a query, variables, and options for configuring pagination
  - Supports flexible path specification for accessing nodes and pageInfo in different response structures
  - Updated existing commands to use this centralized pagination method
- **Consequences**:
  - Reduced code duplication across command classes
  - Simplified command implementations
  - Easier maintenance as pagination logic is in one place
  - More consistent pagination behavior across the application
  - Flexible enough to handle different response structures 

## Progress Bar for Network Operations

- **Decision**: Add visual progress bars for all network operations
- **Context**: Network operations can take time, and users benefit from visual feedback during these operations
- **Implementation**:
  - Added the `tty-progressbar` gem for progress bar rendering
  - Created a `LinearCli::UI::ProgressBar` module to provide consistent progress bar functionality
  - Implemented a null progress bar for non-TTY and test environments
  - Added progress bars to API client methods (query, fetch_paginated_data, get_team_id_by_name)
  - Enhanced pagination with per-page progress visualization
- **Consequences**:
  - Improved user experience with visual feedback during network operations
  - Better indication of operation progress, especially for paginated queries
  - Consistent progress bar styling across all operations
  - No impact on non-TTY environments (CI/CD, scripts) 

## Enhanced Progress Bar with Page Counting

- **Decision**: Enhance progress bars with total page count information
- **Context**: Users need better visibility into pagination progress when fetching large datasets
- **Implementation**:
  - Added an initial count query to determine total number of items before pagination
  - Added a totalCount query to the Issues GraphQL schema
  - Enhanced progress bar to display page numbers (e.g., "page 1/5")
  - Calculated accurate progress percentages based on total page count
  - Gracefully falls back to incremental progress if count is unavailable
- **Consequences**:
  - Improved user experience with clear indication of pagination progress
  - More accurate progress percentage based on actual number of pages
  - Added one additional network call for the count query
  - Better feedback during long-running fetch operations with many pages 

## Progress Bar Optimization for Pagination

- **Decision**: Modify pagination to use direct HTTP requests instead of nested query calls
- **Context**: When fetching paginated data, nested calls to the `query` method were creating multiple progress bars for each API call, creating a confusing user experience
- **Implementation**:
  - Modified `fetch_paginated_data` to make direct HTTP requests using HTTParty instead of calling the `query` method
  - Implemented manual response handling to maintain the same error handling as the `query` method
  - Maintained the same progress bar UX but eliminated nested progress bars
- **Consequences**:
  - Improved user experience with a single progress bar for each operation
  - Clearer visual feedback during pagination operations
  - Consistent error handling with the rest of the application
  - No functional changes to the pagination behavior
  - No impact on non-TTY environments (CI/CD, scripts) 

## Linear API Schema Compatibility Update

- **Decision**: Update the counting query to adapt to Linear API's GraphQL schema changes
- **Context**: The API was returning an error because the "totalCount" field doesn't exist on the IssueConnection type in the Linear API
- **Implementation**:
  - Modified the count_issues query to get nodes instead of using a totalCount field
  - Updated the fetch_paginated_data method to calculate the count by counting the nodes
  - Improved string formatting for progress messages to properly display page information
- **Consequences**:
  - Fixed errors related to the "totalCount" field not existing
  - Improved reliability when interacting with the Linear API
  - Made the pagination system more robust against API schema changes
  - Enhanced user experience with clearer progress information
  - No impact on non-TTY environments (CI/CD, scripts) 

## Exception Handling Best Practices

- **Decision**: Remove exception handling that obscures code or logic issues
- **Context**: The codebase contained try/catch blocks that were silently catching and handling errors in ways that could hide problems
- **Implementation**:
  - Removed exception handling in `fetch_paginated_data` that suppressed count query errors and continued execution
  - Removed special test-mode error handling in `handle_response` that bypassed error validation
  - Retained exception handling used only for resource cleanup (e.g., closing progress bars) where exceptions are re-raised
  - Added activesupport gem as an explicit dependency to properly support required functionality
- **Consequences**:
  - Improved error visibility and debugging by allowing exceptions to properly propagate
  - Better code reliability as issues are no longer hidden behind exception handling
  - More consistent error handling throughout the codebase
  - Cleaner separation between resource cleanup and error handling
  - Ensures that tests properly validate error conditions rather than bypassing them 

## Pagination Count Improvement

- **Decision**: Improve pagination count calculation to use the API's totalCount field
- **Context**: The pagination display was incorrectly showing "page 1 of 1" even when there were multiple pages because it only counted nodes in the first page
- **Implementation**:
  - Modified the pagination count logic to first look for the `totalCount` field in the API response
  - Added fallback to counting nodes only when `totalCount` is not available
  - Properly recalculated total pages based on the accurate total count
- **Consequences**:
  - Fixed incorrect pagination display in progress bars
  - More accurate feedback to users about their position in paginated results
  - Better user experience when navigating large result sets 

## Pagination Fetching Fix

- **Decision**: Fix the logic for fetching all pages of data when using pagination
- **Context**: The pagination system wasn't properly retrieving all pages due to logical errors in the loop control flow
- **Implementation**:
  - Completely redesigned the pagination loop logic to separate API concerns from application logic
  - Added proper handling of the `--all` flag by ignoring the limit parameter when fetch_all is true
  - Changed loop structure to use clearer break conditions instead of complex conditionals
  - Fixed cursor handling to ensure next page is correctly fetched
  - Added separate checks for different termination conditions (fetch_all, limit, hasNextPage)
  - Adjusted default page size from 100 to 20 items per page for better memory usage
- **Consequences**:
  - The pagination system now correctly retrieves all pages when requested
  - The `--all` flag properly overrides any limit settings
  - Improved code readability with clearer separation of concerns
  - Better handling of pagination states for different use cases
  - Improved consistency between pagination display and actual data retrieval
  - Better memory usage with smaller page sizes 

## Adaptive Pagination Progress Display

- **Decision**: Implement an adaptive progress display that estimates the total number of pages
- **Context**: Linear's GraphQL API doesn't provide a totalCount field, making it difficult to accurately show pagination progress
- **Implementation**:
  - Removed dependency on count query which didn't provide accurate total counts
  - Implemented an adaptive estimation approach that starts with a reasonable estimate and adjusts as pages are fetched
  - Added exponential increase of estimated total when approaching the current estimated maximum
  - Updated progress formatting to show "page X of Y+" to indicate an estimate versus exact count
  - Added final exact count display when all pages have been fetched
- **Consequences**:
  - More accurate progress indication without relying on API features not available in Linear
  - Better user experience with clear indication of pagination progress
  - Dynamic adjustment of progress bar as more information becomes available
  - Visual indication of estimated versus exact page counts with the "+" suffix
  - Eliminated errors from attempting to use unsupported API fields 

## Removal of Capitalization Report and Enhanced Engineer Workload Report

- **Decision**: Remove the capitalization report functionality and enhance the engineer workload report
- **Context**: The capitalization report was no longer needed, and we wanted to improve the engineer workload report with additional features
- **Implementation**:
  - Removed the `capitalization` command and related code
  - Added time period filtering to engineer workload report (month, quarter, year, all)
  - Added view type option for summary or detailed display
  - Improved data analysis to use completion date instead of creation date when available
  - Added summary view that shows engineer workload across months in a single table
  - Added more contextual information to displays (issue counts, point totals)
  - Added better handling of period-specific reporting for non-monthly views
- **Consequences**:
  - Simplified codebase by removing unused functionality
  - More flexible workload reporting with time period filtering
  - Better visibility into engineer contributions with summary view
  - More accurate work attribution by prioritizing completion date
  - Improved user experience with more contextual information
  - Consistent period filtering approach across reporting features 

## Defensive Programming for Analytics Processing

- **Decision**: Ensure all analytics processing methods defensively handle nil inputs
- **Context**: There was an issue where `calculate_engineer_project_workload` method would fail with `undefined method '[]' for nil:NilClass` when `issues` parameter was nil
- **Implementation**:
  - Added nil check to convert nil issues to empty arrays
  - Added unit tests to verify nil handling behaviors
  - Added test cases for empty arrays and invalid/incomplete data
- **Consequences**:
  - Improved robustness of the analytics module
  - Better error handling for edge cases
  - Consistent approach to handling nil inputs prevents similar errors
  - Comprehensive test coverage for input validation ensures stability 

## Analytics Module Refactoring

- **Decision**: Refactor analytics module to use service-based architecture
- **Context**: The analytics module had grown large with many responsibilities mixed together, making it hard to test and maintain
- **Implementation**:
  - Extracted data fetching logic into `LinearCli::Services::Analytics::DataFetcher`
  - Extracted period filtering logic into `LinearCli::Services::Analytics::PeriodFilter`
  - Extracted workload calculation logic into `LinearCli::Services::Analytics::WorkloadCalculator`
  - Added comprehensive tests for each service class
  - Improved error handling and edge case coverage
- **Consequences**:
  - Improved maintainability with smaller, focused service classes
  - Better separation of concerns
  - More testable code with clear boundaries
  - More robust handling of edge cases like nil inputs
  - Easier to extend with new functionality in the future
  - Cleaner command class that delegates to specialized services 

## Simplified Engineer Workload Report

- **Decision**: Simplify engineer workload report to only show monthly data going back six months
- **Context**: The workload report had multiple views and time period options which added complexity without providing significant value. Users primarily needed monthly level granularity.
- **Implementation**:
  - Removed period options (month, quarter, year) and standardized on the 6-month view
  - Removed detailed vs. summary view options and combined the most useful elements
  - Simplified the UI to show a monthly summary table followed by project-specific details
  - Improved display format for better readability with less visual clutter
- **Consequences**:
  - Simpler, more focused interface with meaningful defaults
  - Cleaner codebase with fewer conditionals and special cases
  - Better user experience with a consistent report format
  - More maintainable report generation with reduced complexity
  - Preserved the most valuable information (monthly granularity going back 6 months) 

## Enhanced Analytics Module Refactoring

- **Decision**: Further refactor analytics module to improve maintainability and add missing tests
- **Context**: The analytics module had more opportunities for improvement, especially around monthly data processing and display functionality
- **Implementation**:
  - Created a dedicated `MonthlyProcessor` service to handle grouping and processing monthly data
  - Moved the duplicated monthly data processing logic to the new service
  - Added comprehensive tests for all edge cases including nil inputs and date formatting
  - Added tests for the workload display functionality
  - Improved test coverage for both service classes and commands
- **Consequences**:
  - Improved maintainability with clear separation of concerns
  - Better test coverage for edge cases and display functionality
  - More resilient code that properly handles nil inputs and date parsing
  - Easier to extend the analytics functionality in the future
  - Cleaner command class with better delegation to specialized services 