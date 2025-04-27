# Linear CLI Analytics: Developer Guide

This document provides technical details about the analytics module implementation and guidance for developers who want to extend or modify the analytics capabilities.

## Architecture Overview

The analytics module follows a functional programming approach with a clear separation of concerns:

```
                                    ┌────────────────────┐
                                    │                    │
                                    │   Commands::       │
                                    │   Analytics        │
                                    │                    │
                                    └─────────┬──────────┘
                                              │
                                              │ invokes
                                              ▼
┌────────────────────┐  calculates   ┌────────────────────┐  presents   ┌────────────────────┐
│                    │◄──────────────┤                    ├────────────►│                    │
│   API Client       │               │   Analytics::      │             │   Analytics::      │
│   (GraphQL)        │               │   Reporting        │             │   Display          │
│                    │───────────────►                    │             │                    │
└────────────────────┘  provides     └────────────────────┘             └────────────────────┘
                         data
```

### Core Components

1. **Commands::Analytics**: CLI command class that handles user interaction and invokes the appropriate reporting methods
2. **Analytics::Reporting**: Pure data processing module that calculates metrics
3. **Analytics::Display**: Formatting module that presents results in a user-friendly way

## Module Structure

### Analytics::Reporting

This module contains methods to calculate various metrics from Linear data:

- `count_issues_by_status`: Counts issues by status
- `count_issues_by_team`: Counts issues by team
- `calculate_team_completion_rates`: Calculates completion rates for each team
- `generate_report`: Generates a complete report from workspace data

### Services::Analytics

This module contains specialized services for analytics processing:

- `DataFetcher`: Handles API data retrieval
- `PeriodFilter`: Manages time-based filtering
- `MonthlyProcessor`: Processes monthly data for team workload analysis

### Analytics::Display

This module formats and displays the calculated metrics:

- `display_teams`: Displays teams table
- `display_projects`: Displays projects table
- `display_summary_tables`: Displays summary tables
- `display_status_table`: Displays status distribution
- `display_team_table`: Displays team distribution
- `display_completion_table`: Displays completion rates
- `format_percentage`: Formats percentages with color-coding

## Data Structures

### Monthly Team Data

```ruby
{
  "YYYY-MM" => {
    name: String,                      # Month name (e.g., "January 2023")
    issue_count: Integer,              # Total issues for the month
    "team_id" => {
      name: String,                    # Team name
      total_points: Integer,           # Total story points
      completed_points: Integer,       # Completed story points
      projects: {                      # Projects the team worked on
        "project_id" => {
          name: String,                # Project name
          total_points: Integer,       # Total story points
          issues_count: Integer,       # Total number of issues
          contributors: {              # Contributors on the project
            "user_id" => {
              name: String,            # Contributor name
              points: Integer,         # Story points
              issues_count: Integer,   # Number of issues completed
              percentage: Float        # Percentage of project
            }
          }
        }
      },
      contributors: {                  # Team contributors
        "user_id" => {
          name: String,                # Contributor name
          total_points: Integer,       # Total story points
          issues_count: Integer,       # Total number of issues completed
          projects: {                  # Projects contributor worked on
            "project_id" => {
              name: String,            # Project name
              points: Integer,         # Story points
              issues_count: Integer,   # Number of issues completed
              percentage: Float        # Percentage of contributor's work
            }
          }
        }
      }
    }
  }
}
```

## Contributor Metrics

The analytics module calculates and displays the following metrics for each contributor:

1. **Points per Project**: The total number of story points a contributor has earned on a given project.
2. **Project Contribution Percentage**: What percentage of the project's total points the contributor was responsible for.
3. **Issues per Project**: The number of issues a contributor has completed on a given project.
4. **Issue Percentage**: What percentage of the project's total issues the contributor was responsible for.
5. **Points per Issue**: The average number of story points per issue, which can indicate the complexity of work the contributor takes on.
6. **Project Work Percentage**: What percentage of the contributor's total work (measured in points) was spent on this particular project.

These metrics help teams understand work distribution and individual contribution patterns. For example:

```
Kenny Buckler: 83 points (75.5% of project), 15 issues (62.5%), 5.5 points/issue, 34.6% of contributor's work
```

This shows that Kenny earned 83 points, which is 75.5% of the project's total points. He completed 15 issues (62.5% of all issues), with an average of 5.5 points per issue. This project represents 34.6% of Kenny's total work across all projects.

## How to Add a New Analytics Feature

Follow these steps to add a new analytics feature:

1. Define the calculation logic in `Analytics::Reporting` or appropriate service class
2. Create display methods in `Analytics::Display`
3. Add a new command in `Commands::Analytics` to expose the feature

### Example: Adding Cycle Time Analytics

Here's an example of adding cycle time analytics:

1. Add calculation method to `Analytics::Reporting`:

```ruby
def self.calculate_cycle_time(issues)
  issues_with_completion = issues.select { |i| i[:completedAt] && i[:startedAt] }
  return {} if issues_with_completion.empty?
  
  cycle_times = issues_with_completion.map do |issue|
    started_at = Time.parse(issue[:startedAt])
    completed_at = Time.parse(issue[:completedAt])
    
    # Calculate days between start and completion
    days = (completed_at - started_at) / (60 * 60 * 24)
    
    { 
      id: issue[:id],
      title: issue[:title],
      days: days.round(1),
      team: issue.dig(:team, :name) || 'Unassigned'
    }
  end
  
  # Calculate average cycle time by team
  by_team = cycle_times.group_by { |i| i[:team] }
  team_averages = by_team.transform_values do |team_issues|
    avg = team_issues.sum { |i| i[:days] } / team_issues.size
    {
      average_days: avg.round(1),
      issues_count: team_issues.size,
      issues: team_issues
    }
  end
  
  {
    average_cycle_time: (cycle_times.sum { |i| i[:days] } / cycle_times.size).round(1),
    issues_analyzed: cycle_times.size,
    by_team: team_averages,
    issues: cycle_times
  }
end
```

2. Add display method to `Analytics::Display`:

```ruby
def self.display_cycle_time(cycle_time_data)
  return puts 'No cycle time data available.'.yellow unless cycle_time_data&.any?
  
  puts "\n#{'Cycle Time Analysis:'.bold}"
  puts "  Average cycle time: #{cycle_time_data[:average_cycle_time]} days"
  puts "  Issues analyzed: #{cycle_time_data[:issues_analyzed]}"
  
  puts "\n#{'Team Cycle Times:'.bold}"
  rows = []
  cycle_time_data[:by_team].each do |team, data|
    rows << [
      team,
      data[:issues_count],
      data[:average_days]
    ]
  end
  
  # Sort by average days ascending
  rows = rows.sort_by { |row| row[2] }
  
  table = Terminal::Table.new(
    headings: ['Team', 'Issues', 'Avg Days'],
    rows: rows
  )
  
  puts table
end
```

3. Add command to `Commands::Analytics`:

```ruby
desc 'cycle_time', 'Analyze cycle time metrics'
def cycle_time
  issues = fetch_issues_with_dates
  
  cycle_time_data = Analytics::Reporting.calculate_cycle_time(issues)
  Analytics::Display.display_cycle_time(cycle_time_data)
end
```

## Extending Display Formatting

The `Analytics::Display` module uses several Ruby gems for formatting:

- `terminal-table`: For structured tabular output
- `colorize`: For colored terminal output
- `tty-spinner`: For loading indicators

To add new display methods, follow these conventions:

1. Prefix method names with `display_` for clarity
2. Use consistent formatting (tables, colors) to maintain visual consistency
3. Handle edge cases (empty data, nil values) gracefully
4. Support test environments with the `in_test_environment?` check

## Testing Analytics

The analytics module includes comprehensive tests. When adding new features, add tests for:

1. **Calculation logic**: Test the reporting methods with known inputs and expected outputs
2. **Display formatting**: Test that the display methods handle different data scenarios correctly
3. **Edge cases**: Test with empty data, missing fields, and edge cases

## Future Roadmap

The analytics module is planned to include:

- Time-based analytics for trend analysis
- CSV/Excel export capabilities
- Interactive visualizations
- Custom report templates
- Integration with external BI tools
- Velocity metrics and team performance indicators 