# Linear CLI Analytics

The Linear CLI provides powerful analytics capabilities to help you gain insights into your Linear workspace. This document explains the available analytics features and how to use them.

## Overview

The analytics module offers various reports and metrics that help you understand:

- Overall workspace activity
- Team performance and completion rates
- Team workload and contributor distribution
- Project-level analytics

## Available Analytics Commands

### General Reporting

```
linear analytics report [options]
```

This command generates a comprehensive report of your Linear workspace, including:
- Teams and projects summary
- Issue distribution by status and team
- Team completion rates

**Options:**
- `--format TEXT`: Output format, either 'json' or 'table' (default: 'table')

**Examples:**
```bash
# Generate a standard report
linear analytics report

# Export data in JSON format for further analysis
linear analytics report --format json
```

### Team Workload Analysis

```
linear analytics team_workload --team TEAM_NAME [options]
```

This command provides detailed workload analysis for a specific team, showing:
- Monthly contributor breakdown
- Project distribution
- Completion metrics
- Contributor focus analysis

**Options:**
- `--team TEXT`: Team name (required)
- `--format TEXT`: Output format, either 'json' or 'table' (default: 'table')
- `--period TEXT`: Time period to analyze ('month', '3month', '6month', 'year', or 'all') (default: '6month')

**Examples:**
```bash
# Analyze Engineering team workload over the past 6 months
linear analytics team_workload --team "Engineering"

# Analyze Design team workload for the past year
linear analytics team_workload --team "Design" --period year

# Export team workload data in JSON format
linear analytics team_workload --team "Design" --format json
```

## Understanding the Reports

### Team Completion Rates

Team completion rates show what percentage of issues each team has completed. This helps identify:
- Teams that are making good progress
- Teams that might need additional support
- Overall productivity patterns

### Team Workload Analysis

The team workload report provides insights into:

- **Monthly Trends**: How team focus has changed over the past 6 months
- **Contributor Breakdown**: How work is distributed among team members
- **Project Distribution**: Which projects the team is focusing on
- **Contribution Metrics**: Completion rates and story point distribution

## Interpreting the Output

### Color Coding

Percentage values in reports are color-coded for quick visual assessment:
- **Green**: 75% or higher (good)
- **Yellow**: 50-74% (moderate)
- **Red**: Below 50% (needs attention)

### Tables and Formatting

The reports use tables with clear headings to organize data for easy reading. Projects and other key information are highlighted in color to draw attention to important elements.

## Example Workflows

### Team Performance Analysis

```bash
# Generate overall workspace analysis
linear analytics report

# Focus on specific team workload
linear analytics team_workload --team "Engineering"
```

### Historical Analysis

```bash
# Analyze team workload over different time periods
linear analytics team_workload --team "Engineering" --period month
linear analytics team_workload --team "Engineering" --period 3month
linear analytics team_workload --team "Engineering" --period year
```

## Extending Analytics

The analytics module is designed to be extensible. Future enhancements will include:
- Time-based analytics for trend analysis
- Velocity metrics for teams and individuals
- Cycle time and lead time analysis
- Advanced team performance metrics
- Issue aging reports
- Custom analytics dashboards
- CSV/Excel export capabilities
- Interactive visualizations

## Technical Details

The analytics module uses a functional programming approach with stateless methods for better testability and maintainability. It separates concerns between:

- **Data Collection**: Fetching required information from Linear
- **Reporting Logic**: Calculating metrics and analyzing data
- **Display Formatting**: Presenting results in a readable format

This architecture makes it easy to extend with new analytics features while maintaining a consistent interface. 