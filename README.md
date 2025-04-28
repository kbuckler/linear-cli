# Linear CLI

A Ruby command-line tool that allows AI assistants (and humans) to interact directly with the Linear issue tracking system.

> **Note:** This is an independent project and is not officially associated with, supported, or endorsed by Linear. This tool is maintained by community contributors.

## Features

- Create, update, list, and manage Linear issues from the command line
- Filter issues by team, status, assignee, and more
- View issue details and add comments
- List teams and projects
- Analyze team workload with contributor breakdowns and project allocations
- Enhanced logging with contextual information for better debugging and monitoring
- Optimized GraphQL queries with efficient team-centric data fetching
- Configurable timeouts and robust error handling for API communication
- Export detailed reports on your Linear workspace with analytics
- Simple configuration and authentication

## Installation

### Prerequisites

- Ruby 2.7+
- Bundler

### Setup

1. Clone this repository:
   ```
   git clone https://github.com/kbuckler/linear-cli.git
   cd linear-cli
   ```

2. Install dependencies:
   ```
   bundle install
   ```

3. Configure your Linear API key:
   ```
   cp .env.example .env
   ```
   Then edit `.env` and add your Linear API key.

## Usage

```
# List all issues
linear issues list

# List issues for a specific team
linear issues list --team "Engineering"

# List all issues without pagination limits (with adaptive progress display)
linear issues list --all

# View a specific issue
linear issues view ABC-123

# Create a new issue (requires --allow-mutations flag)
linear issues create --allow-mutations --title "Fix login bug" --team "Engineering" --description "Users can't login using SSO"

# Update an issue (requires --allow-mutations flag)
linear issues update --allow-mutations ABC-123 --status "In Progress" --assignee "user@example.com"

# Add a comment to an issue (requires --allow-mutations flag)
linear issues comment --allow-mutations ABC-123 "This is fixed in PR #456"

# List all teams
linear teams list

# List all projects
linear projects list

# Generate a detailed report on your Linear workspace
linear analytics report

# Export report data in JSON format
linear analytics report --format json

# Generate team workload insights (last 6 months)
linear analytics team_workload --team "Engineering"
```

By default, the CLI operates in read-only safe mode to prevent accidental data modifications. Use the `--allow-mutations` flag to enable write operations.

For detailed documentation on all commands and options, see the [Command Reference](docs/COMMANDS.md).

## Getting a Linear API Key

1. Log in to your Linear account
2. Go to Settings > API > Personal API keys
3. Create a new API key with appropriate scopes
4. Copy the API key and add it to your `.env` file

For detailed step-by-step instructions with screenshots, see [How to Obtain a Linear API Key](docs/API_KEY.md).

## Configuration

Linear CLI can be configured using environment variables or a `.env` file.

Key environment variables:
- `LINEAR_API_KEY`: Your Linear API key (required)
- `LINEAR_CLI_DEBUG`: Set to "true" to enable debug logging
- `LINEAR_API_TIMEOUT`: API request timeout in seconds (default: 30)
- `LINEAR_API_CONNECT_TIMEOUT`: Connection timeout in seconds (default: 10)

For details on all configuration options, see the [Configuration Guide](docs/CONFIGURATION.md).

## Analytics and Reporting

```
# View summary tables of your Linear data with analytics
linear analytics report

# Export complete data in JSON format for further analysis
linear analytics report --format json

# Generate team workload report with contributor insights
linear analytics team_workload --team "Engineering"

# Generate team workload report for a specific time period
linear analytics team_workload --team "Engineering" --period month
```

The reporting system provides detailed analytics including:
- Issue distribution by status
- Issue distribution by team
- Team completion rates and productivity metrics
- Team workload insights with monthly contributor breakdowns
- Project allocation analytics showing how team members divide time across projects

The analytics engine features optimized team-centric GraphQL queries that improve performance by reducing the number of API calls needed, which is especially beneficial for large workspaces.

## Development

### Running Tests

```
bundle exec rspec
```

For running specific tests, you can use:

```
# Run tests for a specific file
bundle exec rspec spec/linear_cli/api/client_spec.rb

# Run a specific test (by line number)
bundle exec rspec spec/linear_cli/api/client_spec.rb:70

# Run with detailed output
bundle exec rspec --format doc

# Run the full test suite including RSpec tests and RuboCop
bundle exec rake full_test
```

### Dependencies

The project relies on the following key dependencies:

- Thor: CLI framework
- HTTParty: HTTP client for API requests
- TTY gems: Terminal formatting and display
- RSpec: Testing framework

#### Writing API Client Tests

The API client has a built-in mocking approach for tests:

```ruby
# In your test
before do
  # Set the mock response for the API client
  LinearCli::API::Client.mock_response = {
    'teams' => {
      'nodes' => [
        { 'id' => 'team_123', 'name' => 'Engineering', 'key' => 'ENG' }
      ]
    }
  }
end

after do
  # Reset the mock response after your test
  LinearCli::API::Client.mock_response = nil
end
```

This approach is simpler than using WebMock stubs and avoids issues with HTTP request mocking. The test environment also prevents real API calls by default for safer testing.

### Project Architecture

The Linear CLI follows a modular architecture with clear separation of concerns:

- **Commands**: Thor-based CLI interface (`lib/linear_cli/commands/`)
- **API**: Client and data models for Linear API interaction (`lib/linear_cli/api/`)
- **Analytics**: Reporting and data visualization modules (`lib/linear_cli/analytics/`)
- **Services**: Business logic components (`lib/linear_cli/services/`)
- **UI**: Display formatting and user interface components (`lib/linear_cli/ui/`)
- **Validators**: Input validation and sanitization (`lib/linear_cli/validators/`)

For architectural decisions and design patterns, see [DECISIONS.md](DECISIONS.md).

### Building the Gem

```
bundle exec rake build
```

## Recent Enhancements

- Optimized team-centric GraphQL queries for improved performance
- Enhanced logging with structured contextual information
- Refined team workload analytics with monthly contributor breakdowns
- Added configurable timeouts for all API requests
- Improved pagination with adaptive feedback
- Comprehensive test coverage with automated test safety measures
- RuboCop integration for code quality enforcement

## License

This project is licensed under the MIT License - see the LICENSE file for details.

# Linear CLI Command Reference

## Global Options

These options can be used with any command:

- `--help`: Display help for a specific command
- `--allow-mutations`: Disable read-only safe mode to allow data-modifying operations

By default, the CLI operates in a read-only safe mode to prevent accidental data modifications. Any command that would modify data in Linear (create, update, delete operations) will be blocked unless the `--allow-mutations` flag is provided.