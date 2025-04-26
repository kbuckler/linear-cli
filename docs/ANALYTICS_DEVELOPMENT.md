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
- `calculate_capitalization_metrics`: Calculates software capitalization metrics
- `calculate_team_capitalization`: Analyzes team-level capitalization metrics
- `calculate_engineer_workload`: Analyzes engineer time allocation
- `calculate_project_engineer_workload`: Groups engineers by capitalized project
- `generate_report`: Generates a complete report from workspace data

### Analytics::Display

This module formats and displays the calculated metrics:

- `display_teams`: Displays teams table
- `display_projects`: Displays projects table
- `display_summary_tables`: Displays summary tables
- `display_status_table`: Displays status distribution
- `display_team_table`: Displays team distribution
- `display_completion_table`: Displays completion rates
- `display_capitalization_metrics`: Displays capitalization metrics
- `display_overall_capitalization_rate`: Shows overall capitalization rate
- `display_capitalized_projects`: Lists capitalized projects
- `display_team_capitalization`: Shows team capitalization breakdown
- `display_project_engineer_workload`: Lists engineers by project
- `display_engineer_workload_summary`: Shows engineer workload summary
- `format_percentage`: Formats percentages with color-coding

## Data Structures

### Capitalization Metrics

```ruby
{
  capitalized_count: Integer,          # Number of issues in capitalized projects
  non_capitalized_count: Integer,      # Number of issues in non-capitalized projects
  total_issues: Integer,               # Total number of issues
  capitalization_rate: Float,          # Percentage of issues in capitalized projects
  team_capitalization: Hash,           # Team-level capitalization metrics
  engineer_workload: Hash,             # Engineer workload distribution
  capitalized_projects: Array,         # List of capitalized projects
  project_engineer_workload: Hash      # Engineer grouping by project
}
```

### Team Capitalization

```ruby
{
  "Team Name" => {
    capitalized: Integer,              # Issues on capitalized projects
    non_capitalized: Integer,          # Issues on non-capitalized projects
    total: Integer,                    # Total issues for team
    percentage: Float                  # Capitalization percentage
  }
}
```

### Engineer Workload

```ruby
{
  "Engineer Name" => {
    total_issues: Integer,             # Total assigned issues
    capitalized_issues: Integer,       # Issues on capitalized projects
    total_estimate: Integer,           # Total estimate points
    capitalized_estimate: Integer,     # Estimate points on capitalized projects
    percentage: Float,                 # Percentage of issues on capitalized projects
    estimate_percentage: Float         # Percentage of points on capitalized projects
  }
}
```

### Project Engineer Workload

```ruby
{
  "Project Name" => {
    id: String,                        # Project ID
    total_issues: Integer,             # Total issues in project
    assigned_issues: Integer,          # Assigned issues in project
    engineers: {                       # Engineers working on project
      "Engineer ID" => {
        id: String,                    # Engineer ID
        name: String,                  # Engineer name
        email: String,                 # Engineer email
        issues_count: Integer,         # Number of issues assigned
        total_estimate: Integer,       # Total estimate points
        issues: Array                  # List of assigned issues
      }
    }
  }
}
```

## How to Add a New Analytics Feature

Follow these steps to add a new analytics feature:

1. Define the calculation logic in `Analytics::Reporting`
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
  puts 'Fetching issues data...'
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