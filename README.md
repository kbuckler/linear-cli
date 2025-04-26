# Linear CLI

A Ruby command-line tool that allows AI assistants (and humans) to interact directly with the Linear issue tracking system.

> **Note:** This is an independent project and is not officially associated with, supported, or endorsed by Linear. This tool is maintained by community contributors.

## Features

- Create, update, list, and manage Linear issues from the command line
- Filter issues by team, status, assignee, and more
- View issue details and add comments
- List teams and projects
- Generate test data for reporting and analysis
- Export detailed reports on your Linear workspace
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

# View a specific issue
linear issues view ABC-123

# Create a new issue
linear issues create --title "Fix login bug" --team "Engineering" --description "Users can't login using SSO"

# Update an issue
linear issues update ABC-123 --status "In Progress" --assignee "user@example.com"

# Add a comment to an issue
linear issues comment ABC-123 "This is fixed in PR #456"

# List all teams
linear teams list

# List all projects
linear projects list

# Generate test data in your Linear workspace
linear generator populate

# Get a detailed report on your Linear workspace
linear generator dump

# Export report data in JSON format
linear generator dump --format json
```

For detailed documentation on all commands and options, see the [Command Reference](docs/COMMANDS.md).

## Getting a Linear API Key

1. Log in to your Linear account
2. Go to Settings > API > Personal API keys
3. Create a new API key with appropriate scopes
4. Copy the API key and add it to your `.env` file

For detailed step-by-step instructions with screenshots, see [How to Obtain a Linear API Key](docs/API_KEY.md).

## Configuration

Linear CLI can be configured using environment variables or a `.env` file. For details on all configuration options, see the [Configuration Guide](docs/CONFIGURATION.md).

## Data Generation and Reporting

Linear CLI provides tools to populate your Linear workspace with test data and generate reports:

### Generating Test Data

```
# Create default test data (2 teams, 2 projects per team, 5 issues per project)
linear generator populate

# Customize the amount of data generated
linear generator populate --teams 3 --projects-per-team 4 --issues-per-project 10
```

The data generator uses your existing teams and adds test projects and issues to them, making it easy to set up demo environments or test data for reporting.

### Analyzing Workspace Data

```
# View summary tables of your Linear data
linear generator dump

# Export complete data in JSON format for further analysis
linear generator dump --format json
```

The reporting tool provides insights into:
- Issue counts by status
- Issue counts by team
- Team completion rates
- Overall workspace metrics

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
```

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

This approach is simpler than using WebMock stubs and avoids issues with HTTP request mocking.

### Building the Gem

```
bundle exec rake build
```

## License

This project is licensed under the MIT License - see the LICENSE file for details. 