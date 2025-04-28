# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LinearCli::Services::Analytics::DataFetcher do
  let(:client) { instance_double(LinearCli::API::Client) }
  let(:data_fetcher) { described_class.new(client) }

  describe '#fetch_teams' do
    let(:query) { 'query Teams' }
    let(:teams_data) { [{ 'id' => 'team_1', 'name' => 'Team 1' }, { 'id' => 'team_2', 'name' => 'Team 2' }] }

    before do
      allow(LinearCli::API::Queries::Analytics).to receive(:list_teams).and_return(query)
      allow(client).to receive(:fetch_paginated_data)
        .with(query, { first: 50 }, { fetch_all: true, nodes_path: 'teams', page_info_path: 'teams' })
        .and_return(teams_data)
    end

    it 'fetches teams from the API' do
      teams = data_fetcher.fetch_teams
      expect(teams).to eq(teams_data)
    end

    it 'returns an empty array when the response is empty' do
      allow(client).to receive(:fetch_paginated_data)
        .with(query, { first: 50 }, { fetch_all: true, nodes_path: 'teams', page_info_path: 'teams' })
        .and_return([])
      teams = data_fetcher.fetch_teams
      expect(teams).to eq([])
    end

    it 'returns an empty array when the response nodes are nil' do
      allow(client).to receive(:fetch_paginated_data)
        .with(query, { first: 50 }, { fetch_all: true, nodes_path: 'teams', page_info_path: 'teams' })
        .and_return(nil)
      teams = data_fetcher.fetch_teams
      expect(teams).to eq([])
    end
  end

  describe '#fetch_projects' do
    let(:query) { 'query Projects' }
    let(:projects_data) do
      [
        {
          'id' => 'project_1',
          'name' => 'Project 1',
          'teams' => {
            'nodes' => [
              { 'id' => 'team_1', 'name' => 'Team 1' }
            ]
          }
        },
        {
          'id' => 'project_2',
          'name' => 'Project 2',
          'teams' => {
            'nodes' => [
              { 'id' => 'team_2', 'name' => 'Team 2' }
            ]
          }
        }
      ]
    end
    let(:team_id) { 'team_1' }

    context 'without team_id' do
      before do
        allow(LinearCli::API::Queries::Analytics).to receive(:list_projects).with(team_id: nil).and_return(query)
        allow(client).to receive(:fetch_paginated_data)
          .with(query, { first: 50 }, { fetch_all: true, nodes_path: 'projects', page_info_path: 'projects' })
          .and_return(projects_data)
      end

      it 'fetches all projects from the API' do
        projects = data_fetcher.fetch_projects
        expect(projects).to eq(projects_data)
      end

      it 'returns an empty array when the response is empty' do
        allow(client).to receive(:fetch_paginated_data)
          .with(query, { first: 50 }, { fetch_all: true, nodes_path: 'projects', page_info_path: 'projects' })
          .and_return([])
        projects = data_fetcher.fetch_projects
        expect(projects).to eq([])
      end

      it 'returns an empty array when the response nodes are nil' do
        allow(client).to receive(:fetch_paginated_data)
          .with(query, { first: 50 }, { fetch_all: true, nodes_path: 'projects', page_info_path: 'projects' })
          .and_return(nil)
        projects = data_fetcher.fetch_projects
        expect(projects).to eq([])
      end
    end

    context 'with team_id' do
      before do
        allow(LinearCli::API::Queries::Analytics).to receive(:list_projects).with(team_id: team_id).and_return(query)
        allow(client).to receive(:fetch_paginated_data)
          .with(query, { first: 50 }, { fetch_all: true, nodes_path: 'projects', page_info_path: 'projects' })
          .and_return(projects_data)
      end

      it 'fetches and filters projects for the specified team' do
        projects = data_fetcher.fetch_projects(team_id: team_id)
        expect(projects).to eq([projects_data[0]])
      end

      it 'returns an empty array when no projects match the team' do
        allow(client).to receive(:fetch_paginated_data)
          .with(query, { first: 50 }, { fetch_all: true, nodes_path: 'projects', page_info_path: 'projects' })
          .and_return([])
        projects = data_fetcher.fetch_projects(team_id: team_id)
        expect(projects).to eq([])
      end
    end
  end

  describe '#fetch_issues' do
    let(:query) { 'query {' }
    let(:issues_data) { [{ 'id' => 'issue_1', 'title' => 'Issue 1' }, { 'id' => 'issue_2', 'title' => 'Issue 2' }] }
    let(:team_id) { 'team_1' }

    context 'without team_id' do
      before do
        allow(LinearCli::API::Queries::Analytics).to receive(:list_issues).with(team_id: nil).and_return(query)
        allow(client).to receive(:fetch_paginated_data)
          .with(query, { first: 50 }, { fetch_all: true, nodes_path: 'issues', page_info_path: 'issues' })
          .and_return(issues_data)
      end

      it 'fetches issues from the API' do
        issues = data_fetcher.fetch_issues
        expect(issues).to eq(issues_data)
      end

      it 'returns an empty array when the response is empty' do
        allow(client).to receive(:fetch_paginated_data)
          .with(query, { first: 50 }, { fetch_all: true, nodes_path: 'issues', page_info_path: 'issues' })
          .and_return([])
        issues = data_fetcher.fetch_issues
        expect(issues).to eq([])
      end

      it 'returns an empty array when the response nodes are nil' do
        allow(client).to receive(:fetch_paginated_data)
          .with(query, { first: 50 }, { fetch_all: true, nodes_path: 'issues', page_info_path: 'issues' })
          .and_return(nil)
        issues = data_fetcher.fetch_issues
        expect(issues).to eq([])
      end
    end

    context 'with team_id' do
      before do
        allow(LinearCli::API::Queries::Analytics).to receive(:list_issues).with(team_id: team_id).and_return(query)
        allow(client).to receive(:fetch_paginated_data)
          .with(query, { first: 50, teamId: team_id }, { fetch_all: true, nodes_path: 'issues', page_info_path: 'issues' })
          .and_return(issues_data)
      end

      it 'fetches issues for the specified team' do
        issues = data_fetcher.fetch_issues(team_id: team_id)
        expect(issues).to eq(issues_data)
      end
    end
  end

  describe '#fetch_team_workload_data' do
    let(:team_id) { 'team_1' }
    let(:query) { 'query TeamWorkloadData' }
    let(:issue_pagination_query) { 'query TeamIssuesPagination' }
    let(:projects_data) { [{ 'id' => 'project_1', 'name' => 'Project 1' }] }
    let(:issues_data) { [{ 'id' => 'issue_1', 'title' => 'Issue 1' }] }

    # Initial response with team data and first page of projects and issues
    let(:initial_response) do
      {
        'team' => {
          'id' => team_id,
          'name' => 'Engineering',
          'key' => 'ENG',
          'description' => 'Engineering team',
          'projects' => {
            'nodes' => projects_data,
            'pageInfo' => {
              'hasNextPage' => false,
              'endCursor' => 'cursor1'
            }
          },
          'issues' => {
            'nodes' => issues_data,
            'pageInfo' => {
              'hasNextPage' => false,
              'endCursor' => 'cursor2'
            }
          }
        }
      }
    end

    # Expected final result after fetching all pages
    let(:expected_result) do
      {
        'id' => team_id,
        'name' => 'Engineering',
        'key' => 'ENG',
        'description' => 'Engineering team',
        'projects' => { 'nodes' => projects_data },
        'issues' => { 'nodes' => issues_data }
      }
    end

    before do
      allow(LinearCli::API::Queries::Analytics).to receive(:team_workload_data).with(team_id).and_return(query)

      # Mock the initial query response
      allow(client).to receive(:query).with(
        query,
        {
          teamId: team_id,
          projectsFirst: 50,
          issuesFirst: 50
        }
      ).and_return(initial_response)
    end

    it 'fetches team workload data from the API' do
      result = data_fetcher.fetch_team_workload_data(team_id)
      expect(result).to eq(expected_result)
    end

    it 'returns an empty hash when the team is not found' do
      allow(client).to receive(:query).with(
        query,
        {
          teamId: team_id,
          projectsFirst: 50,
          issuesFirst: 50
        }
      ).and_return({})

      result = data_fetcher.fetch_team_workload_data(team_id)
      expect(result).to eq({})
    end

    context 'with pagination for projects and issues' do
      let(:initial_response_with_pagination) do
        {
          'team' => {
            'id' => team_id,
            'name' => 'Engineering',
            'key' => 'ENG',
            'description' => 'Engineering team',
            'projects' => {
              'nodes' => projects_data,
              'pageInfo' => {
                'hasNextPage' => true,
                'endCursor' => 'project_cursor'
              }
            },
            'issues' => {
              'nodes' => issues_data,
              'pageInfo' => {
                'hasNextPage' => true,
                'endCursor' => 'issue_cursor'
              }
            }
          }
        }
      end

      let(:next_projects_response) do
        {
          'team' => {
            'id' => team_id,
            'name' => 'Engineering',
            'projects' => {
              'nodes' => [{ 'id' => 'project_2', 'name' => 'Project 2' }],
              'pageInfo' => {
                'hasNextPage' => false,
                'endCursor' => 'project_cursor_end'
              }
            }
          }
        }
      end

      let(:next_issues_response) do
        {
          'team' => {
            'id' => team_id,
            'name' => 'Engineering',
            'issues' => {
              'nodes' => [{ 'id' => 'issue_2', 'title' => 'Issue 2' }],
              'pageInfo' => {
                'hasNextPage' => false,
                'endCursor' => 'issue_cursor_end'
              }
            }
          }
        }
      end

      let(:expected_paginated_result) do
        {
          'id' => team_id,
          'name' => 'Engineering',
          'key' => 'ENG',
          'description' => 'Engineering team',
          'projects' => {
            'nodes' => projects_data + [{ 'id' => 'project_2', 'name' => 'Project 2' }]
          },
          'issues' => {
            'nodes' => issues_data + [{ 'id' => 'issue_2', 'title' => 'Issue 2' }]
          }
        }
      end

      before do
        # Initial response with pagination indicators
        allow(client).to receive(:query).with(
          query,
          {
            teamId: team_id,
            projectsFirst: 50,
            issuesFirst: 50
          }
        ).and_return(initial_response_with_pagination)

        # Next page of projects
        allow(client).to receive(:query).with(
          query,
          {
            teamId: team_id,
            projectsFirst: 50,
            projectsAfter: 'project_cursor',
            issuesFirst: 0
          }
        ).and_return(next_projects_response)

        # Allow the issue pagination query - this is the key update
        allow(LinearCli::API::Queries::Analytics).to receive(:team_workload_data).with(team_id).and_return(query)
        allow(client).to receive(:query).with(
          include('query TeamIssuesPagination'),
          {
            teamId: team_id,
            issuesFirst: 50,
            issuesAfter: 'issue_cursor'
          }
        ).and_return(next_issues_response)
      end

      it 'fetches all pages of projects and issues' do
        result = data_fetcher.fetch_team_workload_data(team_id)
        expect(result['projects']['nodes']).to include(*expected_paginated_result['projects']['nodes'])
        expect(result['issues']['nodes']).to include(*expected_paginated_result['issues']['nodes'])
      end
    end
  end
end
