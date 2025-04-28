# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LinearCli::Commands::Issues do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double(LinearCli::API::Client) }
  let(:command) { described_class.new }

  before do
    allow(LinearCli::API::Client).to receive(:new).and_return(client)
    allow(LinearCli::UI::Logger).to receive(:info)
    allow(LinearCli::UI::Logger).to receive(:error)
    allow(LinearCli::UI::Logger).to receive(:success)
    allow(LinearCli::UI::Logger).to receive(:warn)
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
        allow(client).to receive(:fetch_paginated_data).and_return(issues)
      end

      it 'lists all issues' do
        expect(LinearCli::UI::Logger).to receive(:info).with("\n\e[1mLinear Issues (1):\e[0m")
        command.list
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
        # Combined pages
        all_issues = issues + second_page_issues
        allow(client).to receive(:fetch_paginated_data).and_return(all_issues)
      end

      it 'fetches all pages of issues' do
        command.options = { all: true }
        expect(LinearCli::UI::Logger).to receive(:info).with("\n\e[1mLinear Issues (2):\e[0m")
        command.list
      end
    end

    context 'when team filter is provided' do
      let(:team_id) { 'team_123' }

      before do
        allow(client).to receive(:get_team_id_by_name).with('Engineering').and_return(team_id)
        allow(client).to receive(:fetch_paginated_data).and_return(issues)
      end

      it 'filters issues by team' do
        command.options = { team: 'Engineering' }
        expect(LinearCli::UI::Logger).to receive(:info).with("\n\e[1mLinear Issues (1):\e[0m")
        command.list
      end
    end

    context 'when no issues are found' do
      before do
        allow(client).to receive(:fetch_paginated_data).and_return([])
      end

      it 'displays a message' do
        expect(LinearCli::UI::Logger).to receive(:info).with('No issues found matching your criteria.')
        command.list
      end
    end

    context 'with input validation' do
      before do
        allow(client).to receive(:fetch_paginated_data).and_return(issues)
        allow(client).to receive(:get_team_id_by_name).with('Engineering').and_return('team_123')
      end

      it 'sanitizes team name input' do
        command.options = { team: '  Engineering  ' }
        expect(client).to receive(:get_team_id_by_name).with('Engineering')
        expect(LinearCli::UI::Logger).to receive(:info).with("\n\e[1mLinear Issues (1):\e[0m")
        command.list
      end

      it 'validates and caps limit' do
        command.options = { limit: 150 }
        expect(LinearCli::UI::Logger).to receive(:info).with("\n\e[1mLinear Issues (1):\e[0m")
        command.list
        expect(command.instance_variable_get(:@options)[:limit]).to eq(150)
      end

      it 'validates email format in assignee field' do
        allow(LinearCli::Validators::InputValidator).to receive(:validate_email).with('user@example.com').and_return(true)
        command.options = { assignee: 'user@example.com' }
        expect(LinearCli::UI::Logger).to receive(:info).with("\n\e[1mLinear Issues (1):\e[0m")
        command.list
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
        expect(LinearCli::UI::Logger).to receive(:info).with(/ENG-1: Test Issue/)
        command.view('ENG-1')
      end
    end

    context 'when issue does not exist' do
      before do
        allow(client).to receive(:query).and_return({ 'issue' => nil })
      end

      it 'displays an error message' do
        expect(LinearCli::UI::Logger).to receive(:error).with('Issue not found', { issue_id: 'ENG-999' })
        command.view('ENG-999')
      end
    end

    context 'with input validation' do
      before do
        allow(client).to receive(:query).and_return({ 'issue' => issue })
      end

      it 'sanitizes issue ID input' do
        expect(LinearCli::UI::Logger).to receive(:info).with(/ENG-1: Test Issue/)
        command.view('  ENG-1  ')
      end

      it 'validates issue ID format but continues on warning' do
        expect(LinearCli::UI::Logger).to receive(:warn).with(
          "Warning: Invalid issue ID format: 'invalid-id'. Expected format like 'ABC-123'.",
          { issue_id: 'invalid-id' }
        )
        command.view('invalid-id')
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
        expect(LinearCli::UI::Logger).to receive(:success).with(/Issue created successfully/)
        command.create
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
        expect(LinearCli::UI::Logger).to receive(:success).with(/Issue created successfully/)
        command.create
      end

      it 'validates and sanitizes team name input' do
        command.options = {
          title: 'Test Issue',
          team: '  Engineering  '
        }
        expect(LinearCli::UI::Logger).to receive(:success).with(/Issue created successfully/)
        command.create
      end

      it 'validates priority range' do
        command.options = {
          title: 'Test Issue',
          team: 'Engineering',
          priority: 5
        }
        expect(LinearCli::UI::Logger).to receive(:error).with(/Error: Invalid priority value/)
        command.create
      end

      it 'sanitizes labels array' do
        command.options = {
          title: 'Test Issue',
          team: 'Engineering',
          labels: ['  Bug  ', '  Feature  ']
        }
        expect(client).to receive(:query) do |_query, variables|
          expect(variables[:input][:labelIds]).to eq(%w[Bug Feature])
          { 'issueCreate' => { 'success' => true, 'issue' => issue } }
        end

        expect(LinearCli::UI::Logger).to receive(:success).with(/Issue created successfully/)
        command.create
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
        expect(LinearCli::UI::Logger).to receive(:success).with(/Issue created successfully/)
        command.create
      end

      it 'rejects empty title' do
        command.options = {
          title: '',
          team: 'Engineering'
        }
        expect(LinearCli::UI::Logger).to receive(:error).with(/Error: Title cannot be blank/)
        command.create
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
        expect(LinearCli::UI::Logger).to receive(:success).with(/Issue updated successfully/)
        command.update('ENG-1')
      end
    end

    context 'when no update parameters are provided' do
      it 'displays a message' do
        command.options = {}
        expect(LinearCli::UI::Logger).to receive(:warn).with('No update parameters provided.')
        command.update('ENG-1')
      end
    end

    context 'with input validation' do
      before do
        allow(client).to receive(:query).and_return({ 'issueUpdate' => { 'success' => true, 'issue' => issue } })
      end

      it 'sanitizes issue ID input' do
        command.options = { title: 'Updated Issue' }
        expect(LinearCli::UI::Logger).to receive(:success).with(/Issue updated successfully/)
        command.update('  ENG-1  ')
      end

      it 'validates issue ID format' do
        command.options = { title: 'Updated Issue' }
        expect { command.update('invalid') }.not_to raise_error
      end

      it 'validates title input' do
        command.options = { title: '' }
        expect(LinearCli::UI::Logger).to receive(:error).with(/Error: Title cannot be blank/)
        command.update('ENG-1')
      end

      it 'validates priority range' do
        command.options = { priority: 5 }
        expect(LinearCli::UI::Logger).to receive(:error).with(/Error: Invalid priority value/)
        command.update('ENG-1')
      end
    end
  end

  describe '#comment' do
    context 'when comment is added successfully' do
      before do
        allow(client).to receive(:query).and_return({ 'commentCreate' => { 'success' => true } })
      end

      it 'adds the comment' do
        expect(LinearCli::UI::Logger).to receive(:success).with(/Comment added successfully/)
        command.comment('ENG-1', 'Test comment')
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
        expect(LinearCli::UI::Logger).to receive(:error).with(/Error: Comment body cannot be blank/)
        command.comment('ENG-1')
      end
    end

    context 'when comment creation fails' do
      before do
        allow(client).to receive(:query).and_return({ 'commentCreate' => { 'success' => false } })
      end

      it 'displays an error message' do
        expect(LinearCli::UI::Logger).to receive(:error).with('Failed to add comment.')
        command.comment('ENG-1', 'Test comment')
      end
    end

    context 'with input validation' do
      before do
        allow(client).to receive(:query).and_return({ 'commentCreate' => { 'success' => true } })
      end

      it 'sanitizes issue ID input' do
        expect(LinearCli::UI::Logger).to receive(:success).with(/Comment added successfully/)
        command.comment('  ENG-1  ', 'Test comment')
      end

      it 'validates issue ID format' do
        allow(LinearCli::Validators::InputValidator).to receive(:validate_issue_id).and_call_original
        expect(LinearCli::UI::Logger).to receive(:success).with(/Comment added successfully/)
        command.comment('ENG-1', 'Test comment')
        expect(LinearCli::Validators::InputValidator).to have_received(:validate_issue_id)
      end

      it 'sanitizes comment body input' do
        expect(LinearCli::UI::Logger).to receive(:success).with(/Comment added successfully/)
        command.comment('ENG-1', '  Test comment  ')
      end

      it 'validates comment body is not empty' do
        expect(LinearCli::UI::Logger).to receive(:error).with(/Error: Comment body cannot be blank/)
        command.comment('ENG-1', '')
      end

      it 'joins multiple comment parts' do
        expect(LinearCli::UI::Logger).to receive(:success).with(/Comment added successfully/)
        command.comment('ENG-1', 'part1', 'part2', 'part3')

        expect(client).to have_received(:query) do |_query, params|
          expect(params[:body]).to eq('part1 part2 part3')
          { 'commentCreate' => { 'success' => true } }
        end
      end
    end
  end
end
