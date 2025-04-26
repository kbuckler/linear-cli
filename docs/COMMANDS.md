# Linear CLI Command Reference

This document provides detailed information about all commands available in the Linear CLI tool.

## Global Options

These options can be used with any command:

- `--help`: Display help for a specific command

## Issues

Commands for working with Linear issues.

### List Issues

Lists Linear issues with optional filtering.

```
linear issues list [options]
```

**Options:**
- `--team TEXT`: Filter by team name
- `--assignee TEXT`: Filter by assignee email or name
- `--status TEXT`: Filter by status name
- `--limit NUMBER`: Number of issues to fetch (default: 20)
- `--detail`: Show detailed view with more attributes

**Examples:**
```bash
# List all issues
linear issues list

# List issues for a specific team
linear issues list --team "Engineering"

# List issues assigned to a specific person
linear issues list --assignee "john@example.com"

# List issues with a specific status
linear issues list --status "In Progress"

# List with detailed information
linear issues list --detail
```

### View Issue

View detailed information about a specific issue.

```
linear issues view ID
```

**Arguments:**
- `ID`: The issue identifier (e.g., ENG-123)

**Example:**
```bash
linear issues view ENG-123
```

### Create Issue

Create a new Linear issue.

```
linear issues create [options]
```

**Options:**
- `--title TEXT`: Issue title (required)
- `--team TEXT`: Team name (required)
- `--description TEXT`: Issue description
- `--assignee TEXT`: Assignee email or name
- `--status TEXT`: Status name
- `--priority NUMBER`: Priority (0-4, where 1=Urgent, 2=High, 3=Medium, 4=Low)
- `--labels ARRAY`: Comma-separated list of label names

**Examples:**
```bash
# Create a basic issue
linear issues create --title "Fix login bug" --team "Engineering"

# Create an issue with more details
linear issues create --title "Fix login bug" --team "Engineering" --description "Users cannot log in using SSO" --priority 2 --assignee "john@example.com"
```

### Update Issue

Update an existing Linear issue.

```
linear issues update ID [options]
```

**Arguments:**
- `ID`: The issue identifier (e.g., ENG-123)

**Options:**
- `--title TEXT`: Issue title
- `--description TEXT`: Issue description
- `--assignee TEXT`: Assignee email or name
- `--status TEXT`: Status name
- `--priority NUMBER`: Priority (0-4)

**Examples:**
```bash
# Update issue title
linear issues update ENG-123 --title "Updated title"

# Update issue status
linear issues update ENG-123 --status "In Progress"

# Update multiple fields
linear issues update ENG-123 --priority 1 --assignee "jane@example.com"
```

### Comment on Issue

Add a comment to a Linear issue.

```
linear issues comment ID [COMMENT]
```

**Arguments:**
- `ID`: The issue identifier (e.g., ENG-123)
- `COMMENT`: Comment text

**Examples:**
```bash
# Add a comment (quoted)
linear issues comment ENG-123 "This is my comment"

# Add a comment (unquoted)
linear issues comment ENG-123 This is also a valid comment

# Multi-word comments work without quotes
linear issues comment ENG-123 I fixed this in PR #456
```

## Teams

Commands for working with Linear teams.

### List Teams

List all teams in your Linear workspace.

```
linear teams list
```

**Example:**
```bash
linear teams list
```

### View Team

View detailed information about a specific team.

```
linear teams view ID
```

**Arguments:**
- `ID`: The team identifier (e.g., ENG)

**Example:**
```bash
linear teams view ENG
```

## Projects

Commands for working with Linear projects.

### List Projects

List all projects in your Linear workspace.

```
linear projects list
```

**Example:**
```bash
linear projects list
```

### View Project

View detailed information about a specific project.

```
linear projects view ID
```

**Arguments:**
- `ID`: The project identifier

**Example:**
```bash
linear projects view project_123
```

## Analytics

Commands for generating analytics and reports from your Linear workspace data.

### Generate Comprehensive Report

Generate a comprehensive report of your Linear workspace, including team performance metrics, issue distribution, and capitalization data.

```
linear analytics report [options]
```

**Options:**
- `--format TEXT`: Output format, either 'json' or 'table' (default: 'table')
- `--team TEXT`: Filter analytics by team name

**Examples:**
```bash
# Generate a full workspace report
linear analytics report

# Export report as JSON for external analysis
linear analytics report --format json

# Generate report for a specific team
linear analytics report --team "Engineering"
```

**Generated Analytics:**
- **Summary Statistics**: Teams count, projects count, issues count
- **Status Distribution**: Number of issues in each status category
- **Team Distribution**: Number of issues assigned to each team
- **Completion Rates**: Issue completion rate for each team with statistics
- **Capitalization Metrics**: Project capitalization rates (when applicable)

### Capitalization Reporting

Generate detailed software capitalization metrics, useful for financial reporting and tracking development investments.

```
linear analytics capitalization [options]
```

**Options:**
- `--format TEXT`: Output format, either 'json' or 'table' (default: 'table')

**Examples:**
```bash
# Generate capitalization metrics
linear analytics capitalization

# Export capitalization data as JSON
linear analytics capitalization --format json
```

**Generated Analytics:**
- **Overall Capitalization Rate**: Percentage of issues on capitalized projects
- **Capitalized Projects**: List of projects marked for capitalization
- **Team Capitalization**: Team-level breakdown of capitalization rates
- **Engineer Workload**: Time allocation metrics for engineers on capitalized work
- **Project Engineer Distribution**: Engineers grouped by capitalized project

## Data Generator

Commands for generating and analyzing Linear data.

### Populate Linear

Populates your Linear workspace with test data for reporting and analysis. Instead of creating new teams, the command uses your existing teams and creates test projects and issues within them.

```
linear generator populate [options]
```

**Options:**
- `--teams NUMBER`: Number of teams to use from your workspace (default: 2)
- `--projects-per-team NUMBER`: Number of projects per team (default: 2)
- `--issues-per-project NUMBER`: Number of issues per project (default: 5)

**Examples:**
```bash
# Create default test data (2 teams, 2 projects per team, 5 issues per project)
linear generator populate

# Create a larger dataset
linear generator populate --teams 3 --projects-per-team 3 --issues-per-project 8
```

**Notes:**
- The command requires at least one team to exist in your Linear workspace
- If a team doesn't have any projects, the command will create them
- Issues are created with random priorities and linked to the appropriate projects
- If the system can't create projects due to permissions, it will attempt to create issues directly under the team

### Dump Linear Data

> **Note**: This command is deprecated. Please use `linear analytics report` instead.

Extracts detailed reporting data from your Linear workspace and provides analytics on the data.

```
linear generator dump [options]
```

**Options:**
- `--format TEXT`: Output format, either 'json' or 'table' (default: 'table')

**Examples:**
```bash
# Display summary tables of Linear data (deprecated)
linear generator dump

# Export data as JSON for external analysis (deprecated)
linear generator dump --format json
``` 