require 'spec_helper'

RSpec.describe LinearCli::Commands::Generator do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double(LinearCli::API::Client) }
  let(:command) { described_class.new }
  let(:data_generator) { instance_double(LinearCli::API::DataGenerator) }

  before do
    allow(LinearCli::API::Client).to receive(:new).and_return(client)
    allow(LinearCli::API::DataGenerator).to receive(:new).with(client).and_return(data_generator)

    # Allow any query call with default response
    allow(client).to receive(:query).with(any_args).and_return({})
  end

  describe '#populate' do
    let(:existing_teams) do
      [
        {
          'id' => 'team_1',
          'name' => 'Engineering',
          'key' => 'ENG',
          'description' => 'Engineering team'
        },
        {
          'id' => 'team_2',
          'name' => 'Design',
          'key' => 'DSG',
          'description' => 'Design team'
        }
      ]
    end

    let(:team_members) do
      [
        {
          'id' => 'member_1',
          'name' => 'Real User 1',
          'email' => 'user1@example.com'
        },
        {
          'id' => 'member_2',
          'name' => 'Real User 2',
          'email' => 'user2@example.com'
        }
      ]
    end

    let(:created_project) do
      {
        'id' => 'project_1',
        'name' => 'Test Project 1',
        'state' => 'started',
        'teams' => {
          'nodes' => [
            { 'id' => 'team_1', 'name' => 'Engineering' }
          ]
        }
      }
    end

    let(:created_issue) do
      {
        'id' => 'issue_1',
        'title' => 'Test Issue 1-1',
        'team' => { 'name' => 'Engineering' }
      }
    end

    let(:team_states) do
      [
        { 'id' => 'state_1', 'name' => 'Backlog', 'type' => 'backlog' },
        { 'id' => 'state_2', 'name' => 'In Progress', 'type' => 'started' },
        { 'id' => 'state_3', 'name' => 'Done', 'type' => 'completed' }
      ]
    end

    before do
      # Mock fetch_existing_teams query explicitly
      allow(client).to receive(:query)
        .with(any_args)
        .and_return({ 'teams' => { 'nodes' => existing_teams } })

      # Mock team members query
      allow(data_generator).to receive(:get_team_members)
        .with(any_args)
        .and_return(team_members)

      # Mock team states query
      allow(data_generator).to receive(:get_team_states)
        .with(any_args)
        .and_return(team_states)

      # Mock project creation
      allow(data_generator).to receive(:create_project)
        .with(
          instance_of(String),
          instance_of(String),
          instance_of(String)
        )
        .and_return(created_project)

      # Mock issue creation
      allow(data_generator).to receive(:create_issue)
        .with(
          instance_of(String),
          instance_of(String),
          instance_of(Hash)
        )
        .and_return(created_issue)

      # Mock issue update
      allow(data_generator).to receive(:update_issue)
        .with(
          instance_of(String),
          instance_of(Hash)
        )
        .and_return(created_issue)
    end

    it 'fetches existing teams' do
      expect(client).to receive(:query).with(any_args).at_least(:once)

      command.options = {
        teams: 1,
        projects_per_team: 1,
        issues_per_project: 1,
        assign_to_users: true,
        assignment_percentage: 70
      }

      expect { command.populate }.to output.to_stdout
    end

    it 'shows error message when no teams exist' do
      allow(client).to receive(:query).and_return({ 'teams' => { 'nodes' => [] } })

      command.options = {
        teams: 1,
        projects_per_team: 1,
        issues_per_project: 1,
        assign_to_users: true,
        assignment_percentage: 70
      }

      expect { command.populate }.to output(/No existing teams found/).to_stdout
    end

    it 'creates projects and issues for existing teams' do
      command.options = {
        teams: 1,
        projects_per_team: 1,
        issues_per_project: 1,
        assign_to_users: true,
        assignment_percentage: 70
      }

      expect(data_generator).to receive(:create_project).once
      expect(data_generator).to receive(:create_issue).once

      expect { command.populate }.to output(/Generation complete/).to_stdout
    end

    it 'limits the number of teams based on input' do
      command.options = {
        teams: 1,
        projects_per_team: 1,
        issues_per_project: 1,
        assign_to_users: true,
        assignment_percentage: 70
      }

      # Should only use one team even though two exist
      expect(data_generator).to receive(:create_project).exactly(1).times

      expect { command.populate }.to output.to_stdout
    end

    it 'handles errors when creating projects' do
      command.options = {
        teams: 1,
        projects_per_team: 1,
        issues_per_project: 1,
        assign_to_users: true,
        assignment_percentage: 70,
        months: 1 # Reduce to 1 month to simplify test
      }

      allow(data_generator).to receive(:create_project).and_raise('Access denied')

      # Should still try to create the issue, but we're not expecting it will succeed
      # Just stub it to prevent further errors
      allow(data_generator).to receive(:create_issue).with(any_args).and_return(created_issue)

      expect { command.populate }.to output(/Warning: Could not create project/).to_stdout
    end

    it 'handles errors when creating issues' do
      command.options = {
        teams: 1,
        projects_per_team: 1,
        issues_per_project: 1,
        assign_to_users: true,
        assignment_percentage: 70,
        months: 1 # Reduce to 1 month to simplify test
      }

      allow(data_generator).to receive(:create_project)
        .with(any_args)
        .and_return(created_project)

      allow(data_generator).to receive(:create_issue)
        .with(any_args)
        .and_raise('Access denied')

      # Adjust expectation to match the actual error message in the code
      expect { command.populate }.to output(/Error creating issue/).to_stdout
    end

    it 'assigns issues to real users when available' do
      command.options = {
        teams: 1,
        projects_per_team: 1,
        issues_per_project: 1,
        assign_to_users: true,
        assignment_percentage: 100 # Always assign to real users in test
      }

      expect(data_generator).to receive(:get_team_members).at_least(:once)

      # Expect the issue creation to include a real user ID
      expect(data_generator).to receive(:create_issue) do |title, team_id, options|
        expect(options).to include(:assignee_id)
        expect(team_members.map { |m| m['id'] }).to include(options[:assignee_id])
        created_issue
      end

      expect { command.populate }.to output.to_stdout
    end

    it 'falls back to fictional engineers when no real users available' do
      command.options = {
        teams: 1,
        projects_per_team: 1,
        issues_per_project: 1,
        assign_to_users: true,
        assignment_percentage: 100 # Always try to assign to real users
      }

      # Return empty list of team members
      allow(data_generator).to receive(:get_team_members).and_return([])

      # Issue should be created without assignee_id since we fall back to fictional engineers
      expect(data_generator).to receive(:create_issue) do |title, team_id, options|
        expect(options).not_to include(:assignee_id)
        created_issue
      end

      expect { command.populate }.to output(/Warning: No team members found/).to_stdout
    end
  end

  describe '#dump' do
    it 'is deprecated and outputs a deprecation message' do
      expect { command.dump }.to output(/DEPRECATED: The dump command has been removed/).to_stdout
    end
  end
end
