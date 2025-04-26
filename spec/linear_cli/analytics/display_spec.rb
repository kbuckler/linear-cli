require 'spec_helper'

RSpec.describe LinearCli::Analytics::Display do
  let(:teams) do
    [
      { 'id' => 'team1', 'name' => 'Engineering', 'key' => 'ENG' },
      { 'id' => 'team2', 'name' => 'Design', 'key' => 'DSG' }
    ]
  end

  let(:projects) do
    [
      { 'id' => 'proj1', 'name' => 'Project A', 'state' => 'started' },
      { 'id' => 'proj2', 'name' => 'Project B', 'state' => 'completed' }
    ]
  end

  let(:status_data) do
    {
      'Todo' => 5,
      'In Progress' => 8,
      'Done' => 3
    }
  end

  let(:team_data) do
    {
      'Engineering' => 10,
      'Design' => 6
    }
  end

  let(:completion_data) do
    {
      'Engineering' => { total: 10, completed: 4, rate: 40.0 },
      'Design' => { total: 6, completed: 2, rate: 33.33 }
    }
  end

  let(:summary) do
    {
      teams_count: 2,
      projects_count: 3,
      issues_count: 16,
      issues_by_status: status_data,
      issues_by_team: team_data,
      team_completion_rates: completion_data
    }
  end

  before do
    # Stub puts to prevent output during tests
    allow(described_class).to receive(:puts)
    # Force test environment
    allow(described_class).to receive(:in_test_environment?).and_return(true)
  end

  describe '.in_test_environment?' do
    it 'is used in RSpec context' do
      # Reset the stub to call the actual method
      allow(described_class).to receive(:in_test_environment?).and_call_original

      # Check that the method exists and is callable, without testing actual implementation
      expect { described_class.in_test_environment? }.not_to raise_error
    end
  end

  describe '.display_teams' do
    it 'displays a table of teams' do
      expect(described_class).to receive(:puts).with("\nTeams:")
      expect(described_class).to receive(:puts).with('Name | Key | ID')
      expect(described_class).to receive(:puts).with('-----+-----+----')
      expect(described_class).to receive(:puts).with('Engineering | ENG | team1')
      expect(described_class).to receive(:puts).with('Design | DSG | team2')

      described_class.display_teams(teams)
    end

    it 'handles empty teams array' do
      expect(described_class).not_to receive(:puts)
      described_class.display_teams([])
    end
  end

  describe '.display_projects' do
    it 'displays a table of projects' do
      expect(described_class).to receive(:puts).with("\nProjects:")
      expect(described_class).to receive(:puts).with('Name | State | ID')
      expect(described_class).to receive(:puts).with('-----+-------+----')
      expect(described_class).to receive(:puts).with('Project A | started | proj1')
      expect(described_class).to receive(:puts).with('Project B | completed | proj2')

      described_class.display_projects(projects)
    end

    it 'handles empty projects array' do
      expect(described_class).not_to receive(:puts)
      described_class.display_projects([])
    end
  end

  describe '.display_summary_tables' do
    it 'displays summary information and all related tables' do
      expect(described_class).to receive(:puts).with("\nSummary:")
      expect(described_class).to receive(:puts).with('Teams: 2')
      expect(described_class).to receive(:puts).with('Projects: 3')
      expect(described_class).to receive(:puts).with('Issues: 16')

      # Ensure it calls the individual table display methods
      expect(described_class).to receive(:display_status_table).with(status_data)
      expect(described_class).to receive(:display_team_table).with(team_data)
      expect(described_class).to receive(:display_completion_table).with(completion_data)

      described_class.display_summary_tables(summary)
    end
  end

  describe '.display_status_table' do
    it 'displays a table of issue statuses' do
      expect(described_class).to receive(:puts).with("\nIssues by Status:")
      expect(described_class).to receive(:puts).with('Status | Count')
      expect(described_class).to receive(:puts).with('-------+------')
      expect(described_class).to receive(:puts).with('Todo | 5')
      expect(described_class).to receive(:puts).with('In Progress | 8')
      expect(described_class).to receive(:puts).with('Done | 3')

      described_class.display_status_table(status_data)
    end
  end

  describe '.display_team_table' do
    it 'displays a table of issues by team' do
      expect(described_class).to receive(:puts).with("\nIssues by Team:")
      expect(described_class).to receive(:puts).with('Team | Count')
      expect(described_class).to receive(:puts).with('------+------')
      expect(described_class).to receive(:puts).with('Engineering | 10')
      expect(described_class).to receive(:puts).with('Design | 6')

      described_class.display_team_table(team_data)
    end
  end

  describe '.display_completion_table' do
    it 'displays a table of team completion rates' do
      expect(described_class).to receive(:puts).with("\nTeam Completion Rates:")
      expect(described_class).to receive(:puts).with('Team | Completed | Total | Rate (%)')
      expect(described_class).to receive(:puts).with('------+-----------+-------+--------')
      expect(described_class).to receive(:puts).with('Engineering | 4 | 10 | 40.0')
      expect(described_class).to receive(:puts).with('Design | 2 | 6 | 33.33')

      described_class.display_completion_table(completion_data)
    end
  end
end
