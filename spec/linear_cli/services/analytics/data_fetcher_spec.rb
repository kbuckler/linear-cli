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
end
