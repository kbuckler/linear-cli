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