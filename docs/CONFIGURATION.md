# Linear CLI Configuration

This document explains how to configure the Linear CLI tool.

## Environment Variables

Linear CLI uses environment variables for configuration. You can set these in your shell or use a `.env` file in the project directory.

### Required Configuration

#### LINEAR_API_KEY

Your Linear API key is required to authenticate with the Linear API.

```
LINEAR_API_KEY=lin_api_xxxxxxxxxxxxxxxxxxxxx
```

Get your API key from Linear by following these steps:
1. Log in to your Linear account at [linear.app](https://linear.app)
2. Go to **Settings** > **API** > **Personal API keys**
3. Click **New Key**
4. Name your key (e.g., "Linear CLI")
5. Select the appropriate scopes:
   - **Issues**: Read/Write
   - **Teams**: Read
   - **Projects**: Read
   - **Comments**: Read/Write
6. Click **Create**
7. Copy the generated API key and save it in your `.env` file or set it as an environment variable

### Optional Configuration

#### LINEAR_API_URL

By default, Linear CLI uses the Linear GraphQL API endpoint at `https://api.linear.app/graphql`. If you need to use a different endpoint (e.g., for a proxy or custom configuration), you can set this variable:

```
LINEAR_API_URL=https://your-custom-endpoint.example.com/graphql
```

#### DEFAULT_TEAM

If you work primarily with one team, you can set a default team to avoid specifying it in commands:

```
DEFAULT_TEAM=Engineering
```

## Configuration File

The Linear CLI looks for a `.env` file in the current directory. You can create this file by copying the provided example:

```bash
cp .env.example .env
```

Then edit the `.env` file to add your API key and any other configuration options.

Example `.env` file:
```
# Linear API Key (required)
LINEAR_API_KEY=lin_api_xxxxxxxxxxxxxxxxxxxxx

# Linear API URL (optional)
# LINEAR_API_URL=https://api.linear.app/graphql

# Default team (optional)
DEFAULT_TEAM=Engineering
```

## Security Considerations

- Never commit your `.env` file to version control
- Keep your Linear API key secure
- Consider using a key with limited scopes for production environments
- Rotate your API keys periodically for security 