# Linear CLI Analytics

The Linear CLI provides powerful analytics capabilities to help you gain insights into your Linear workspace. This document explains the available analytics features and how to use them.

## Overview

The analytics module offers various reports and metrics that help you understand:

- Overall workspace activity
- Team performance and completion rates
- Software capitalization tracking
- Engineer workload distribution
- Project-level analytics

## Available Analytics Commands

### General Reporting

```
linear analytics report
```

This command generates a comprehensive report of your Linear workspace, including:
- Teams and projects summary
- Issue distribution by status and team
- Team completion rates
- Capitalization metrics (if applicable)

### Capitalization Reporting

```
linear analytics capitalization
```

This specialized command provides detailed software capitalization metrics, useful for financial reporting and tracking development investments.

#### Capitalization Features

The capitalization reporting includes:
- Overall capitalization rate
- List of capitalized projects (identified by labels)
- Team-level capitalization breakdown
- Engineer workload on capitalized projects
- Distribution of work between capitalized and non-capitalized projects

## Understanding the Reports

### Team Completion Rates

Team completion rates show what percentage of issues each team has completed. This helps identify:
- Teams that are making good progress
- Teams that might need additional support
- Overall productivity patterns

### Capitalization Metrics

Software capitalization metrics are important for financial reporting in many organizations. They help track which development efforts should be capitalized (treated as fixed assets) versus expensed.

#### How Capitalization is Determined

Projects are considered "capitalized" if they have any of the following labels:
- `capitalization`
- `capex`
- `fixed asset`

The tool analyzes all issues in these projects and provides metrics on how much work is being done on capitalized vs. non-capitalized projects.

#### Capitalization Report Components

1. **Overall Capitalization Rate**: The percentage of all issues that are part of capitalized projects

2. **Capitalized Projects**: A list of all projects identified as capitalized based on their labels

3. **Team Capitalization Rates**: Shows what percentage of each team's work is on capitalized projects

4. **Engineers by Capitalized Project**: Lists all engineers working on each capitalized project, including their assigned issues and estimated points

5. **Engineer Workload Summary**: Shows how each engineer's time is distributed between capitalized and non-capitalized work

## Interpreting the Output

### Color Coding

Percentage values in reports are color-coded for quick visual assessment:
- **Green**: 75% or higher (good)
- **Yellow**: 50-74% (moderate)
- **Red**: Below 50% (needs attention)

### Tables and Formatting

The reports use tables with clear headings to organize data for easy reading. Projects and other key information are highlighted in color to draw attention to important elements.

## Example Workflows

### Financial Reporting

```bash
# Generate capitalization metrics for quarterly financial reporting
linear analytics capitalization

# Export the results for finance team
linear analytics capitalization --output=json > q2_capitalization.json
```

### Performance Analysis

```bash
# Generate overall workspace analysis
linear analytics report

# Focus on specific teams
linear analytics report --team="Engineering"
```

## Extending Analytics

The analytics module is designed to be extensible. Future enhancements will include:
- Time-based analytics (trends over time)
- Velocity metrics for teams and individuals
- Cycle time and lead time analysis
- Advanced team performance metrics
- Issue aging reports
- Custom analytics dashboards

## Technical Details

The analytics module uses a functional programming approach with stateless methods for better testability and maintainability. It separates concerns between:

- **Data Collection**: Fetching required information from Linear
- **Reporting Logic**: Calculating metrics and analyzing data
- **Display Formatting**: Presenting results in a readable format

This architecture makes it easy to extend with new analytics features while maintaining a consistent interface. 