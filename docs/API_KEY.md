# Obtaining a Linear API Key

This guide will walk you through the process of obtaining an API key from Linear to use with the Linear CLI tool.

## What is a Linear API Key?

A Linear API key is a secure token that allows the Linear CLI to authenticate with your Linear account and perform actions on your behalf. The key determines what permissions the CLI has (e.g., reading issues, creating comments, etc.).

## Steps to Create an API Key

1. **Log in to Linear**

   Go to [linear.app](https://linear.app) and log in with your account credentials.

2. **Navigate to API Settings**

   In the bottom left of the screen, click on your profile picture or initials, then select **Settings**.

   ![Navigate to Settings](https://i.imgur.com/VPfMYd9.png)

3. **Go to API Section**

   In the left sidebar of the Settings page, click on **API**.

   ![API Section](https://i.imgur.com/oWDXTOH.png)

4. **Personal API Keys**

   Make sure you're on the **Personal API keys** tab.

   ![Personal API Keys](https://i.imgur.com/fUZXz4Y.png)

5. **Create a New Key**

   Click the **New Key** button.

   ![New Key Button](https://i.imgur.com/GkUBQhk.png)

6. **Configure the Key**

   - **Label**: Give your key a descriptive name, such as "Linear CLI"
   - **Scopes**: Select the permissions your key will have:
     - **Issues (Read & Write)**: Required to list, view, create, and update issues
     - **Comments (Read & Write)**: Required to add comments to issues
     - **Teams (Read)**: Required to list and view teams
     - **Projects (Read)**: Required to list and view projects

   ![Configure Key](https://i.imgur.com/Hb4qPvo.png)

7. **Create the Key**

   Click the **Create** button.

8. **Copy Your API Key**

   After creating the key, Linear will display the API key once. **Copy this key immediately** as you won't be able to see it again.

   ![Copy API Key](https://i.imgur.com/vp8Q9XT.png)

9. **Store the Key Securely**

   Add the key to your `.env` file:

   ```
   LINEAR_API_KEY=lin_api_xxxxxxxxxxxxxxxxxxxxx
   ```

   Or set it as an environment variable in your shell:

   ```bash
   export LINEAR_API_KEY=lin_api_xxxxxxxxxxxxxxxxxxxxx
   ```

## Managing Your API Keys

- You can view all of your existing API keys in the API settings
- You can delete a key at any time if you believe it's been compromised
- Consider rotating your keys periodically for better security

## Security Best Practices

- **Never share your API key** in public repositories, screenshots, or with unauthorized individuals
- Do not commit your `.env` file to version control
- Use environment variables when deploying in CI/CD environments
- Only grant the minimum necessary permissions to your API key
- Create different keys for different tools/purposes to limit exposure

## Troubleshooting

If you encounter authentication errors when using the Linear CLI, check that:

1. Your API key is correctly set in the `.env` file or as an environment variable
2. The API key has not been revoked in the Linear settings
3. The API key has the necessary permissions for the commands you're trying to run 