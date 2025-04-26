# Linear CLI

A Ruby command-line tool that allows AI assistants (and humans) to interact directly with the Linear issue tracking system.

## Features

- Create, update, list, and manage Linear issues from the command line
- Filter issues by team, status, assignee, and more
- View issue details and add comments
- List teams and projects
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