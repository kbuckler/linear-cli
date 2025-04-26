require 'spec_helper'

RSpec.describe LinearCli::Commands::Issues do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double(LinearCli::API::Client) }
  let(:command) { described_class.new }

  before do
    allow(LinearCli::API::Client).to receive(:new).and_return(client)
  end

  describe '#list' do
    let(:issues) do
      [
        {
          'identifier' => 'ENG-1',
          'title' => 'Test Issue',
          'state' => { 'name' => 'Todo' },
          'assignee' => { 'name' => 'John Doe' },
          'team' => { 'name' => 'Engineering' }
        }
      ]
    end

    context 'when no filters are provided' do
      before do
        allow(client).to receive(:query).and_return({ 'issues' => { 'nodes' => issues } })
      end

      it 'lists all issues' do
        expect { command.list }.to output(/Linear Issues \(1\):/).to_stdout
      end
    end

    context 'when team filter is provided' do
      let(:team_id) { 'team_123' }

      before do
        allow(client).to receive(:get_team_id_by_name).with('Engineering').and_return(team_id)
        allow(client).to receive(:query).and_return({ 'issues' => { 'nodes' => issues } })
      end

      it 'filters issues by team' do
        command.options = { team: 'Engineering' }
        expect { command.list }.to output(/Linear Issues \(1\):/).to_stdout
      end
    end

    context 'when no issues are found' do
      before do
        allow(client).to receive(:query).and_return({ 'issues' => { 'nodes' => [] } })
      end

      it 'displays a message' do
        expect { command.list }.to output(/No issues found matching your criteria/).to_stdout
      end
    end
  end

  describe '#view' do
    let(:issue) do
      {
        'identifier' => 'ENG-1',
        'title' => 'Test Issue',
        'state' => { 'name' => 'Todo' },
        'team' => { 'name' => 'Engineering' },
        'assignee' => { 'name' => 'John Doe' },
        'priority' => 2,
        'description' => 'Test description',
        'comments' => {
          'nodes' => [
            {
              'body' => 'Test comment',
              'user' => { 'name' => 'John Doe' },
              'createdAt' => '2024-01-01T00:00:00Z'
            }
          ]
        }
      }
    end

    context 'when issue exists' do
      before do
        allow(client).to receive(:query).and_return({ 'issue' => issue })
      end

      it 'displays issue details' do
        expect { command.view('ENG-1') }.to output(/ENG-1: Test Issue/).to_stdout
      end
    end

    context 'when issue does not exist' do
      before do
        allow(client).to receive(:query).and_return({ 'issue' => nil })
      end

      it 'displays an error message' do
        expect { command.view('ENG-999') }.to output(/Issue not found: ENG-999/).to_stdout
      end
    end
  end

  describe '#create' do
    let(:team_id) { 'team_123' }
    let(:issue) do
      {
        'identifier' => 'ENG-1',
        'title' => 'Test Issue',
        'url' => 'https://linear.app/issue/ENG-1'
      }
    end

    context 'when all required fields are provided' do
      before do
        allow(client).to receive(:get_team_id_by_name).with('Engineering').and_return(team_id)
        allow(client).to receive(:query).and_return({ 'issueCreate' => { 'success' => true, 'issue' => issue } })
      end

      it 'creates the issue' do
        command.options = {
          title: 'Test Issue',
          team: 'Engineering',
          description: 'Test description'
        }
        expect { command.create }.to output(/Issue created successfully/).to_stdout
      end
    end

    context 'when team does not exist' do
      before do
        allow(client).to receive(:get_team_id_by_name)
          .with('NonExistentTeam')
          .and_raise(RuntimeError, "Team 'NonExistentTeam' not found")
      end

      it 'displays an error message' do
        command.options = {
          title: 'Test Issue',
          team: 'NonExistentTeam'
        }
        expect { command.create }.to raise_error(RuntimeError, /Team 'NonExistentTeam' not found/)
      end
    end
  end

  describe '#update' do
    let(:issue) do
      {
        'identifier' => 'ENG-1',
        'title' => 'Updated Issue',
        'url' => 'https://linear.app/issue/ENG-1'
      }
    end

    context 'when update is successful' do
      before do
        allow(client).to receive(:query).and_return({ 'issueUpdate' => { 'success' => true, 'issue' => issue } })
      end

      it 'updates the issue' do
        command.options = { title: 'Updated Issue' }
        expect { command.update('ENG-1') }.to output(/Issue updated successfully/).to_stdout
      end
    end

    context 'when no update parameters are provided' do
      it 'displays a message' do
        command.options = {}
        expect { command.update('ENG-1') }.to output(/No update parameters provided/).to_stdout
      end
    end
  end

  describe '#comment' do
    context 'when comment is added successfully' do
      before do
        allow(client).to receive(:query).and_return({ 'commentCreate' => { 'success' => true } })
      end

      it 'adds the comment' do
        expect { command.comment('ENG-1', 'Test comment') }.to output(/Comment added successfully/).to_stdout
      end
    end

    context 'when comment creation fails' do
      before do
        allow(client).to receive(:query).and_return({ 'commentCreate' => { 'success' => false } })
      end

      it 'displays an error message' do
        expect { command.comment('ENG-1', 'Test comment') }.to output(/Failed to add comment/).to_stdout
      end
    end
  end
end 