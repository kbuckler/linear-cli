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

## Dependency Management
- **Bundler**: We will use Bundler for managing gem dependencies. 