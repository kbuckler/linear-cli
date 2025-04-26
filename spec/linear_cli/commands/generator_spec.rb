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

    let(:created_project) do
      {
        'id' => 'project_1',
        'name' => 'Test Project 1',
        'state' => 'started'
      }
    end

    let(:created_issue) do
      {
        'id' => 'issue_1',
        'title' => 'Test Issue 1-1',
        'team' => { 'name' => 'Engineering' }
      }
    end

    before do
      # Mock fetch_existing_teams query explicitly
      allow(client).to receive(:query)
        .with(any_args)
        .and_return({ 'teams' => { 'nodes' => existing_teams } })

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
    end

    it 'fetches existing teams' do
      expect(client).to receive(:query).with(any_args).at_least(:once)

      command.options = { teams: 1, projects_per_team: 1, issues_per_project: 1 }

      expect { command.populate }.to output.to_stdout
    end

    it 'shows error message when no teams exist' do
      allow(client).to receive(:query).and_return({ 'teams' => { 'nodes' => [] } })

      command.options = { teams: 1, projects_per_team: 1, issues_per_project: 1 }

      expect { command.populate }.to output(/No existing teams found/).to_stdout
    end

    it 'creates projects and issues for existing teams' do
      command.options = { teams: 1, projects_per_team: 1, issues_per_project: 1 }

      expect(data_generator).to receive(:create_project).once
      expect(data_generator).to receive(:create_issue).once

      expect { command.populate }.to output(/Generation complete/).to_stdout
    end

    it 'limits the number of teams based on input' do
      command.options = { teams: 1, projects_per_team: 1, issues_per_project: 1 }

      # Should only use one team even though two exist
      expect(data_generator).to receive(:create_project).exactly(1).times

      expect { command.populate }.to output.to_stdout
    end

    it 'handles errors when creating projects' do
      command.options = { teams: 1, projects_per_team: 1, issues_per_project: 1 }

      allow(data_generator).to receive(:create_project).and_raise('Access denied')

      # Should attempt to create issues directly for the team when project creation fails
      expect(data_generator).to receive(:create_issue)

      expect { command.populate }.to output(/Warning: Could not create project/).to_stdout
    end

    it 'handles errors when creating issues' do
      command.options = { teams: 1, projects_per_team: 1, issues_per_project: 1 }

      allow(data_generator).to receive(:create_project).and_raise('Access denied')
      allow(data_generator).to receive(:create_issue).and_raise('Access denied')

      expect { command.populate }.to output(/Error creating issue/).to_stdout
    end
  end

  describe '#dump' do
    let(:teams_data) do
      [
        {
          'id' => 'team_1',
          'name' => 'Engineering',
          'key' => 'ENG'
        }
      ]
    end

    let(:projects_data) do
      [
        {
          'id' => 'project_1',
          'name' => 'Test Project',
          'state' => 'started'
        }
      ]
    end

    let(:issues_data) do
      [
        {
          'id' => 'issue_1',
          'identifier' => 'ENG-1',
          'title' => 'Test Issue',
          'state' => { 'name' => 'Todo' },
          'team' => { 'name' => 'Engineering', 'key' => 'ENG' },
          'priority' => 2,
          'completedAt' => nil
        }
      ]
    end

    before do
      # Mock the data fetching methods
      allow(client).to receive(:query)
        .with(any_args)
        .and_return(
          { 'teams' => { 'nodes' => teams_data } },
          { 'projects' => { 'nodes' => projects_data } },
          { 'issues' => { 'nodes' => issues_data } }
        )
    end

    it 'fetches and displays data in table format by default' do
      command.options = { format: 'table' }

      expect { command.dump }.to output(/Summary:/).to_stdout
      expect { command.dump }.to output(/Issues by Status:/).to_stdout
      expect { command.dump }.to output(/Team Completion Rates:/).to_stdout
    end

    it 'outputs JSON format when requested' do
      command.options = { format: 'json' }

      expect { command.dump }.to output(/"teams":/).to_stdout
      expect { command.dump }.to output(/"projects":/).to_stdout
      expect { command.dump }.to output(/"issues":/).to_stdout
    end

    it 'validates format option' do
      command.options = { format: 'invalid' }

      expect { command.dump }.to raise_error(/Invalid format/)
    end
  end
end
