require 'spec_helper'

RSpec.describe LinearCli::Analytics::Reporting do
  let(:issues) do
    [
      {
        'id' => 'issue1',
        'title' => 'Bug fix',
        'state' => { 'name' => 'In Progress' },
        'team' => { 'name' => 'Engineering' },
        'completedAt' => nil,
        'project' => { 'id' => 'proj1', 'name' => 'Project A' }
      },
      {
        'id' => 'issue2',
        'title' => 'New feature',
        'state' => { 'name' => 'Done' },
        'team' => { 'name' => 'Engineering' },
        'completedAt' => '2023-05-15T10:00:00Z',
        'project' => { 'id' => 'proj1', 'name' => 'Project A' }
      },
      {
        'id' => 'issue3',
        'title' => 'Design update',
        'state' => { 'name' => 'In Progress' },
        'team' => { 'name' => 'Design' },
        'completedAt' => nil,
        'project' => { 'id' => 'proj2', 'name' => 'Project B' },
        'labels' => { 'nodes' => [{ 'name' => 'bug' }] }
      },
      {
        'id' => 'issue4',
        'title' => 'Refactoring',
        'state' => { 'name' => 'Backlog' },
        'team' => { 'name' => 'Engineering' },
        'completedAt' => nil,
        'labels' => { 'nodes' => [{ 'name' => 'capitalization' }] }
      }
    ]
  end

  let(:teams) do
    [
      { 'id' => 'team1', 'name' => 'Engineering', 'key' => 'ENG' },
      { 'id' => 'team2', 'name' => 'Design', 'key' => 'DES' }
    ]
  end

  let(:projects) do
    [
      {
        'id' => 'proj1',
        'name' => 'Project A',
        'labels' => { 'nodes' => [{ 'name' => 'capitalization' }] }
      },
      {
        'id' => 'proj2',
        'name' => 'Project B',
        'labels' => { 'nodes' => [{ 'name' => 'feature' }] }
      }
    ]
  end

  describe '.count_issues_by_status' do
    it 'correctly counts issues by their status' do
      result = described_class.count_issues_by_status(issues)

      expect(result).to eq({
                             'In Progress' => 2,
                             'Done' => 1,
                             'Backlog' => 1
                           })
    end

    it 'handles empty issues array' do
      result = described_class.count_issues_by_status([])

      expect(result).to eq({})
    end

    it 'uses "Unknown" for issues with no state' do
      issues_with_no_state = [{ 'id' => 'issue5', 'title' => 'No state' }]

      result = described_class.count_issues_by_status(issues_with_no_state)

      expect(result).to eq({ 'Unknown' => 1 })
    end
  end

  describe '.count_issues_by_team' do
    it 'correctly counts issues by their team' do
      result = described_class.count_issues_by_team(issues)

      expect(result).to eq({
                             'Engineering' => 3,
                             'Design' => 1
                           })
    end

    it 'handles empty issues array' do
      result = described_class.count_issues_by_team([])

      expect(result).to eq({})
    end

    it 'uses "Unknown" for issues with no team' do
      issues_with_no_team = [{ 'id' => 'issue5', 'title' => 'No team' }]

      result = described_class.count_issues_by_team(issues_with_no_team)

      expect(result).to eq({ 'Unknown' => 1 })
    end
  end

  describe '.calculate_team_completion_rates' do
    it 'correctly calculates completion rates for each team' do
      result = described_class.calculate_team_completion_rates(issues)

      expect(result['Engineering'][:total]).to eq(3)
      expect(result['Engineering'][:completed]).to eq(1)
      expect(result['Engineering'][:rate]).to eq(33.33)

      expect(result['Design'][:total]).to eq(1)
      expect(result['Design'][:completed]).to eq(0)
      expect(result['Design'][:rate]).to eq(0)
    end

    it 'handles empty issues array' do
      result = described_class.calculate_team_completion_rates([])

      expect(result).to eq({})
    end
  end

  describe '.calculate_capitalization_metrics' do
    it 'identifies capitalized issues by project labels' do
      result = described_class.calculate_capitalization_metrics(issues, projects)

      # Project A has capitalization label, so its 2 issues should be capitalized
      # Issue4 has capitalization label directly, so it should be capitalized too
      expect(result[:capitalized_count]).to eq(3)
      expect(result[:non_capitalized_count]).to eq(1) # Only issue3 isn't capitalized
      expect(result[:total_issues]).to eq(4)
      expect(result[:capitalization_rate]).to eq(75.0)
    end

    it 'correctly calculates team capitalization metrics' do
      result = described_class.calculate_capitalization_metrics(issues, projects)

      expect(result[:team_capitalization]['Engineering'][:capitalized]).to eq(3)
      expect(result[:team_capitalization]['Engineering'][:non_capitalized]).to eq(0)
      expect(result[:team_capitalization]['Engineering'][:total]).to eq(3)
      expect(result[:team_capitalization]['Engineering'][:capitalization_rate]).to eq(100.0)

      expect(result[:team_capitalization]['Design'][:capitalized]).to eq(0)
      expect(result[:team_capitalization]['Design'][:non_capitalized]).to eq(1)
      expect(result[:team_capitalization]['Design'][:total]).to eq(1)
      expect(result[:team_capitalization]['Design'][:capitalization_rate]).to eq(0)
    end

    it 'falls back to issue labels when project labels are not available' do
      # Remove project information to test fallback
      issues_without_projects = issues.map do |issue|
        issue.delete('project')
        issue
      end

      result = described_class.calculate_capitalization_metrics(issues_without_projects, [])

      # Only issue4 has capitalization label
      expect(result[:capitalized_count]).to eq(1)
      expect(result[:capitalization_rate]).to eq(25.0)
    end
  end

  describe '.generate_report' do
    it 'generates a complete report with all data sections' do
      report = described_class.generate_report(teams, projects, issues)

      expect(report[:teams]).to eq(teams)
      expect(report[:projects]).to eq(projects)
      expect(report[:issues]).to eq(issues)

      expect(report[:summary][:teams_count]).to eq(2)
      expect(report[:summary][:projects_count]).to eq(2)
      expect(report[:summary][:issues_count]).to eq(4)

      expect(report[:summary][:issues_by_status]).to be_a(Hash)
      expect(report[:summary][:issues_by_team]).to be_a(Hash)
      expect(report[:summary][:team_completion_rates]).to be_a(Hash)
      expect(report[:summary][:capitalization_metrics]).to be_a(Hash)
    end
  end

  describe '.format_table_row' do
    it 'formats values as a pipe-separated string' do
      result = described_class.format_table_row(['Column 1', 'Column 2', 'Column 3'])

      expect(result).to eq('Column 1 | Column 2 | Column 3')
    end
  end

  describe '.format_table_header' do
    it 'formats headers with a separator line' do
      result = described_class.format_table_header(%w[Name Status Priority])

      # Verify format includes headers and separator, without being too strict about exact spacing
      expect(result).to include('Name | Status | Priority')
      expect(result).to include('-') # Contains separator characters
      expect(result.lines.count).to eq(2) # Has 2 lines (header and separator)
    end
  end

  describe '.format_simple_table' do
    it 'creates a complete text table with headers and rows' do
      headers = %w[Name Status]
      rows = [
        ['Task 1', 'Done'],
        ['Task 2', 'In Progress']
      ]

      result = described_class.format_simple_table(headers, rows)

      expected = [
        'Name | Status',
        '-----+-------',
        'Task 1 | Done',
        'Task 2 | In Progress'
      ].join("\n")

      expect(result).to eq(expected)
    end
  end
end
