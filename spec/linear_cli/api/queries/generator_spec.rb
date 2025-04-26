require 'spec_helper'

RSpec.describe LinearCli::API::Queries::Generator do
  describe '.list_teams_for_generator' do
    it 'returns a valid GraphQL query' do
      query = described_class.list_teams_for_generator

      expect(query).to include('query Teams')
      expect(query).to include('teams')
      expect(query).to include('nodes')
      expect(query).to include('id')
      expect(query).to include('name')
      expect(query).to include('key')
      expect(query).to include('description')
    end
  end

  describe '.get_team_states' do
    it 'returns a valid GraphQL query with variable' do
      query = described_class.get_team_states

      expect(query).to include('query TeamWorkflowStates($teamId: String!)')
      expect(query).to include('team(id: $teamId)')
      expect(query).to include('states')
      expect(query).to include('nodes')
      expect(query).to include('id')
      expect(query).to include('name')
      expect(query).to include('color')
      expect(query).to include('type')
    end
  end

  describe '.get_team_members' do
    it 'returns a valid GraphQL query with variable' do
      query = described_class.get_team_members

      expect(query).to include('query TeamMembers($teamId: String!)')
      expect(query).to include('team(id: $teamId)')
      expect(query).to include('members')
      expect(query).to include('nodes')
      expect(query).to include('id')
      expect(query).to include('name')
      expect(query).to include('email')
    end
  end

  describe '.create_team' do
    it 'returns a valid GraphQL mutation' do
      query = described_class.create_team

      expect(query).to include('mutation CreateTeam($input: TeamCreateInput!)')
      expect(query).to include('teamCreate(input: $input)')
      expect(query).to include('success')
      expect(query).to include('team')
      expect(query).to include('id')
      expect(query).to include('name')
      expect(query).to include('key')
      expect(query).to include('description')
    end
  end

  describe '.create_project' do
    it 'returns a valid GraphQL mutation' do
      query = described_class.create_project

      expect(query).to include('mutation CreateProject($input: ProjectCreateInput!)')
      expect(query).to include('projectCreate(input: $input)')
      expect(query).to include('success')
      expect(query).to include('project')
      expect(query).to include('id')
      expect(query).to include('name')
      expect(query).to include('description')
      expect(query).to include('state')
      expect(query).to include('teams')
    end
  end

  describe '.create_issue' do
    it 'returns a valid GraphQL mutation' do
      query = described_class.create_issue

      expect(query).to include('mutation CreateIssue($input: IssueCreateInput!)')
      expect(query).to include('issueCreate(input: $input)')
      expect(query).to include('success')
      expect(query).to include('issue')
      expect(query).to include('id')
      expect(query).to include('identifier')
      expect(query).to include('title')
      expect(query).to include('description')
      expect(query).to include('state')
      expect(query).to include('assignee')
      expect(query).to include('team')
      expect(query).to include('priority')
      expect(query).to include('project')
      expect(query).to include('estimate')
      expect(query).to include('startedAt')
      expect(query).to include('completedAt')
      expect(query).to include('createdAt')
    end
  end

  describe '.list_projects_for_reporting' do
    it 'returns a valid GraphQL query' do
      query = described_class.list_projects_for_reporting

      expect(query).to include('query Projects')
      expect(query).to include('projects')
      expect(query).to include('nodes')
      expect(query).to include('id')
      expect(query).to include('name')
      expect(query).to include('description')
      expect(query).to include('state')
      expect(query).to include('progress')
      expect(query).to include('teams')
      expect(query).to include('issues')
    end
  end

  describe '.list_issues_for_reporting' do
    it 'returns a valid GraphQL query' do
      query = described_class.list_issues_for_reporting

      expect(query).to include('query')
      expect(query).to include('issues(first: 100)')
      expect(query).to include('nodes')
      expect(query).to include('id')
      expect(query).to include('identifier')
      expect(query).to include('title')
      expect(query).to include('description')
      expect(query).to include('state')
      expect(query).to include('assignee')
      expect(query).to include('team')
      expect(query).to include('priority')
      expect(query).to include('project')
      expect(query).to include('createdAt')
      expect(query).to include('updatedAt')
      expect(query).to include('completedAt')
    end
  end
end
