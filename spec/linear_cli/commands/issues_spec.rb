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
        allow(client).to receive(:query).and_return({ 'issues' => {
                                                      'nodes' => issues,
                                                      'pageInfo' => {
                                                        'hasNextPage' => false,
                                                        'endCursor' => 'cursor123'
                                                      }
                                                    } })
      end

      it 'lists all issues' do
        expect { command.list }.to output(/Linear Issues \(1\):/).to_stdout
      end
    end

    context 'when pagination is requested with --all flag' do
      let(:second_page_issues) do
        [
          {
            'identifier' => 'ENG-2',
            'title' => 'Second Issue',
            'state' => { 'name' => 'In Progress' },
            'assignee' => { 'name' => 'Jane Doe' },
            'team' => { 'name' => 'Engineering' }
          }
        ]
      end

      before do
        # First page response
        allow(client).to receive(:query).with(
          LinearCli::API::Queries::Issues.list_issues,
          hash_including(first: 100)
        ).and_return({
                       'issues' => {
                         'nodes' => issues,
                         'pageInfo' => {
                           'hasNextPage' => true,
                           'endCursor' => 'cursor123'
                         }
                       }
                     }).once

        # Second page response
        allow(client).to receive(:query).with(
          LinearCli::API::Queries::Issues.list_issues,
          hash_including(after: 'cursor123')
        ).and_return({
                       'issues' => {
                         'nodes' => second_page_issues,
                         'pageInfo' => {
                           'hasNextPage' => false,
                           'endCursor' => 'cursor456'
                         }
                       }
                     }).once
      end

      it 'fetches all pages of issues' do
        command.options = { all: true }
        expect { command.list }.to output(/Linear Issues \(2\):/).to_stdout
        expect(client).to have_received(:query).exactly(2).times
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

    context 'with input validation' do
      before do
        allow(client).to receive(:query).and_return({ 'issues' => { 'nodes' => issues } })
        allow(client).to receive(:get_team_id_by_name).with('Engineering').and_return('team_123')
      end

      it 'sanitizes team name input' do
        command.options = { team: '  Engineering  ' }
        expect(client).to receive(:get_team_id_by_name).with('Engineering')
        expect { command.list }.to output.to_stdout
      end

      it 'validates and caps limit' do
        command.options = { limit: 150 }
        expect { command.list }.to output.to_stdout
        expect(command.instance_variable_get(:@options)[:limit]).to eq(150)
      end

      it 'validates email format in assignee field' do
        allow(LinearCli::Validators::InputValidator).to receive(:validate_email).with('user@example.com').and_return(true)
        command.options = { assignee: 'user@example.com' }
        expect { command.list }.to output.to_stdout
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

    context 'with input validation' do
      before do
        allow(client).to receive(:query).and_return({ 'issue' => issue })
      end

      it 'sanitizes issue ID input' do
        expect { command.view('  ENG-1  ') }.to output(/ENG-1: Test Issue/).to_stdout
      end

      it 'validates issue ID format but continues on warning' do
        expect { command.view('invalid-id') }.to output(/Warning: Invalid issue ID format/).to_stdout
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

    context 'with input validation' do
      before do
        allow(client).to receive(:get_team_id_by_name).with('Engineering').and_return(team_id)
        allow(client).to receive(:query).and_return({ 'issueCreate' => { 'success' => true, 'issue' => issue } })
      end

      it 'validates and sanitizes title input' do
        command.options = {
          title: '  Test Issue  ',
          team: 'Engineering'
        }
        expect { command.create }.to output(/Issue created successfully/).to_stdout
      end

      it 'validates and sanitizes team name input' do
        command.options = {
          title: 'Test Issue',
          team: '  Engineering  '
        }
        expect { command.create }.to output(/Issue created successfully/).to_stdout
      end

      it 'validates priority range' do
        command.options = {
          title: 'Test Issue',
          team: 'Engineering',
          priority: 5
        }
        expect { command.create }.to output(/Error: Invalid priority value/).to_stdout
      end

      it 'sanitizes labels array' do
        command.options = {
          title: 'Test Issue',
          team: 'Engineering',
          labels: ['  Bug  ', '  Feature  ']
        }
        expect(client).to receive(:query) do |query, variables|
          expect(variables[:input][:labelIds]).to eq(%w[Bug Feature])
          { 'issueCreate' => { 'success' => true, 'issue' => issue } }
        end

        expect { command.create }.to output(/Issue created successfully/).to_stdout
      end

      it 'validates email format for assignee' do
        command.options = {
          title: 'Test Issue',
          team: 'Engineering',
          assignee: 'invalid-email'
        }
        expect { command.create }.not_to raise_error

        command.options = {
          title: 'Test Issue',
          team: 'Engineering',
          assignee: 'user@example.com'
        }
        expect { command.create }.to output(/Issue created successfully/).to_stdout
      end

      it 'rejects empty title' do
        command.options = {
          title: '',
          team: 'Engineering'
        }
        expect { command.create }.to output(/Error: Title cannot be blank/).to_stdout
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

    context 'with input validation' do
      before do
        allow(client).to receive(:query).and_return({ 'issueUpdate' => { 'success' => true, 'issue' => issue } })
      end

      it 'sanitizes issue ID input' do
        command.options = { title: 'Updated Issue' }
        expect { command.update('  ENG-1  ') }.to output(/Issue updated successfully/).to_stdout
      end

      it 'validates issue ID format' do
        command.options = { title: 'Updated Issue' }
        expect { command.update('invalid') }.not_to raise_error
      end

      it 'validates title input' do
        command.options = { title: '' }
        expect { command.update('ENG-1') }.to output(/Error: Title cannot be blank/).to_stdout
      end

      it 'validates priority range' do
        command.options = { priority: 5 }
        expect { command.update('ENG-1') }.to output(/Error: Invalid priority value/).to_stdout
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

      it 'passes the correct parameters to the API' do
        expect(client).to receive(:query).with(
          LinearCli::API::Queries::Issues.create_comment,
          { issueId: 'ENG-1', body: 'Test comment' }
        ).and_return({ 'commentCreate' => { 'success' => true } })

        command.comment('eng-1', 'Test comment')
      end
    end

    context 'when comment body is empty' do
      it 'displays an error message' do
        expect { command.comment('ENG-1') }.to output(/Error: Comment body cannot be blank/).to_stdout
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

    context 'with input validation' do
      before do
        allow(client).to receive(:query).and_return({ 'commentCreate' => { 'success' => true } })
      end

      it 'sanitizes issue ID input' do
        expect { command.comment('  ENG-1  ', 'Test comment') }.to output(/Comment added successfully/).to_stdout
      end

      it 'validates issue ID format' do
        allow(LinearCli::Validators::InputValidator).to receive(:validate_issue_id).and_call_original
        expect { command.comment('ENG-1', 'Test comment') }.to output(/Comment added successfully/).to_stdout
        expect(LinearCli::Validators::InputValidator).to have_received(:validate_issue_id)
      end

      it 'sanitizes comment body input' do
        expect { command.comment('ENG-1', '  Test comment  ') }.to output(/Comment added successfully/).to_stdout
      end

      it 'validates comment body is not empty' do
        expect { command.comment('ENG-1', '') }.to output(/Error: Comment body cannot be blank/).to_stdout
      end

      it 'joins multiple comment parts' do
        expect { command.comment('ENG-1', 'part1', 'part2', 'part3') }.to output(/Comment added successfully/).to_stdout

        expect(client).to have_received(:query) do |query, params|
          expect(params[:body]).to eq('part1 part2 part3')
          { 'commentCreate' => { 'success' => true } }
        end
      end
    end
  end
end
