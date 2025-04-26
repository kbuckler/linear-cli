require 'spec_helper'

RSpec.describe LinearCli::API::DataGenerator do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double(LinearCli::API::Client) }
  let(:generator) { described_class.new(client) }

  describe '#create_team' do
    let(:team_data) do
      {
        'teamCreate' => {
          'success' => true,
          'team' => {
            'id' => 'team_123',
            'name' => 'Test Team',
            'key' => 'TEST',
            'description' => 'Test description'
          }
        }
      }
    end

    it 'creates a team with all parameters' do
      expect(client).to receive(:query)
        .with(
          instance_of(String),
          { input: { name: 'Test Team', key: 'TEST', description: 'Test description' } }
        )
        .and_return(team_data)

      team = generator.create_team('Test Team', 'TEST', 'Test description')

      expect(team['id']).to eq('team_123')
      expect(team['name']).to eq('Test Team')
      expect(team['key']).to eq('TEST')
      expect(generator.created_teams).to include(team)
    end

    it 'creates a team with only required parameters' do
      expect(client).to receive(:query)
        .with(
          instance_of(String),
          { input: { name: 'Test Team' } }
        )
        .and_return(team_data)

      team = generator.create_team('Test Team')

      expect(team['id']).to eq('team_123')
      expect(generator.created_teams).to include(team)
    end

    it 'raises an error when team creation fails' do
      failed_response = { 'teamCreate' => { 'success' => false } }

      expect(client).to receive(:query).and_return(failed_response)

      expect { generator.create_team('Test Team') }.to raise_error(/Failed to create team/)
    end
  end

  describe '#create_project' do
    let(:project_data) do
      {
        'projectCreate' => {
          'success' => true,
          'project' => {
            'id' => 'project_123',
            'name' => 'Test Project',
            'description' => 'Test description',
            'state' => 'started',
            'teams' => {
              'nodes' => [
                { 'id' => 'team_123', 'name' => 'Test Team' }
              ]
            }
          }
        }
      }
    end

    it 'creates a project with all parameters' do
      expect(client).to receive(:query)
        .with(
          instance_of(String),
          {
            input: {
              name: 'Test Project',
              teamIds: ['team_123'],
              state: 'planned',
              description: 'Test description'
            }
          }
        )
        .and_return(project_data)

      project = generator.create_project('Test Project', 'team_123', 'Test description', 'planned')

      expect(project['id']).to eq('project_123')
      expect(project['name']).to eq('Test Project')
      expect(generator.created_projects).to include(project)
    end

    it 'creates a project with default state' do
      expect(client).to receive(:query)
        .with(
          instance_of(String),
          {
            input: {
              name: 'Test Project',
              teamIds: ['team_123'],
              state: 'started'
            }
          }
        )
        .and_return(project_data)

      project = generator.create_project('Test Project', 'team_123')

      expect(project['id']).to eq('project_123')
      expect(project['state']).to eq('started')
      expect(generator.created_projects).to include(project)
    end

    it 'raises an error when project creation fails' do
      failed_response = { 'projectCreate' => { 'success' => false } }

      expect(client).to receive(:query).and_return(failed_response)

      expect { generator.create_project('Test Project', 'team_123') }.to raise_error(/Failed to create project/)
    end
  end

  describe '#create_issue' do
    let(:issue_data) do
      {
        'issueCreate' => {
          'success' => true,
          'issue' => {
            'id' => 'issue_123',
            'identifier' => 'TEST-1',
            'title' => 'Test Issue',
            'description' => 'Test description',
            'state' => { 'id' => 'state_123', 'name' => 'Todo' },
            'assignee' => { 'id' => 'user_123', 'name' => 'Test User' },
            'team' => { 'id' => 'team_123', 'name' => 'Test Team' },
            'priority' => 2,
            'project' => { 'id' => 'project_123', 'name' => 'Test Project' }
          }
        }
      }
    end

    it 'creates an issue with all options' do
      options = {
        description: 'Test description',
        assignee_id: 'user_123',
        state_id: 'state_123',
        priority: 2,
        project_id: 'project_123'
      }

      expect(client).to receive(:query)
        .with(
          instance_of(String),
          {
            input: {
              title: 'Test Issue',
              teamId: 'team_123',
              description: 'Test description',
              assigneeId: 'user_123',
              stateId: 'state_123',
              priority: 2,
              projectId: 'project_123'
            }
          }
        )
        .and_return(issue_data)

      issue = generator.create_issue('Test Issue', 'team_123', options)

      expect(issue['id']).to eq('issue_123')
      expect(issue['title']).to eq('Test Issue')
      expect(generator.created_issues).to include(issue)
    end

    it 'creates an issue with minimal options' do
      expect(client).to receive(:query)
        .with(
          instance_of(String),
          {
            input: {
              title: 'Test Issue',
              teamId: 'team_123'
            }
          }
        )
        .and_return(issue_data)

      issue = generator.create_issue('Test Issue', 'team_123')

      expect(issue['id']).to eq('issue_123')
      expect(generator.created_issues).to include(issue)
    end

    it 'raises an error when issue creation fails' do
      failed_response = { 'issueCreate' => { 'success' => false } }

      expect(client).to receive(:query).and_return(failed_response)

      expect { generator.create_issue('Test Issue', 'team_123') }.to raise_error(/Failed to create issue/)
    end
  end

  describe '#get_team_states' do
    let(:states_data) do
      {
        'team' => {
          'states' => {
            'nodes' => [
              {
                'id' => 'state_1',
                'name' => 'Todo',
                'description' => 'Not started',
                'color' => '#c0c0c0',
                'type' => 'backlog'
              },
              {
                'id' => 'state_2',
                'name' => 'In Progress',
                'description' => 'Currently working on',
                'color' => '#0000ff',
                'type' => 'started'
              }
            ]
          }
        }
      }
    end

    it 'returns team workflow states' do
      expect(client).to receive(:query)
        .with(
          instance_of(String),
          { teamId: 'team_123' }
        )
        .and_return(states_data)

      states = generator.get_team_states('team_123')

      expect(states.size).to eq(2)
      expect(states.first['name']).to eq('Todo')
      expect(states.last['name']).to eq('In Progress')
    end

    it 'returns empty array when no states exist' do
      expect(client).to receive(:query)
        .and_return({ 'team' => { 'states' => { 'nodes' => [] } } })

      states = generator.get_team_states('team_123')

      expect(states).to be_empty
    end
  end

  describe '#get_team_members' do
    let(:members_data) do
      {
        'team' => {
          'members' => {
            'nodes' => [
              {
                'id' => 'user_1',
                'name' => 'John Doe',
                'email' => 'john@example.com'
              },
              {
                'id' => 'user_2',
                'name' => 'Jane Smith',
                'email' => 'jane@example.com'
              }
            ]
          }
        }
      }
    end

    it 'returns team members' do
      expect(client).to receive(:query)
        .with(
          instance_of(String),
          { teamId: 'team_123' }
        )
        .and_return(members_data)

      members = generator.get_team_members('team_123')

      expect(members.size).to eq(2)
      expect(members.first['name']).to eq('John Doe')
      expect(members.last['name']).to eq('Jane Smith')
    end

    it 'returns empty array when no members exist' do
      expect(client).to receive(:query)
        .and_return({ 'team' => { 'members' => { 'nodes' => [] } } })

      members = generator.get_team_members('team_123')

      expect(members).to be_empty
    end
  end

  describe '#generate_dataset' do
    let(:team) do
      {
        'id' => 'team_123',
        'name' => 'Test Team',
        'key' => 'TEST'
      }
    end

    let(:states) do
      [
        { 'id' => 'state_1', 'name' => 'Todo' }
      ]
    end

    let(:members) do
      [
        { 'id' => 'user_1', 'name' => 'John Doe' }
      ]
    end

    let(:project) do
      {
        'id' => 'project_123',
        'name' => 'Test Project'
      }
    end

    let(:issue) do
      {
        'id' => 'issue_123',
        'title' => 'Test Issue'
      }
    end

    before do
      allow(generator).to receive(:create_team).and_return(team)
      allow(generator).to receive(:get_team_states).and_return(states)
      allow(generator).to receive(:get_team_members).and_return(members)
      allow(generator).to receive(:create_project).and_return(project)
      allow(generator).to receive(:create_issue).and_return(issue)
    end

    it 'generates dataset with default parameters' do
      result = generator.generate_dataset

      expect(generator).to have_received(:create_team).exactly(2).times
      expect(generator).to have_received(:create_project).exactly(4).times  # 2 teams * 2 projects
      expect(generator).to have_received(:create_issue).exactly(20).times   # 4 projects * 5 issues

      expect(result[:created][:teams]).to eq(2)
      expect(result[:created][:projects]).to eq(4)
      expect(result[:created][:issues]).to eq(20)
    end

    it 'uses the provided parameters' do
      result = generator.generate_dataset(1, 1, 2)

      expect(generator).to have_received(:create_team).exactly(1).times
      expect(generator).to have_received(:create_project).exactly(1).times
      expect(generator).to have_received(:create_issue).exactly(2).times

      expect(result[:created][:teams]).to eq(1)
      expect(result[:created][:projects]).to eq(1)
      expect(result[:created][:issues]).to eq(2)
    end
  end
end
