require 'spec_helper'

RSpec.describe LinearCli::Services::Analytics::DataFetcher do
  let(:client) { instance_double(LinearCli::API::Client) }
  let(:data_fetcher) { described_class.new(client) }

  describe '#fetch_teams' do
    let(:query) { 'query Teams' }
    let(:response) do
      {
        'teams' => {
          'nodes' => [
            { 'id' => 'team_1', 'name' => 'Team 1' },
            { 'id' => 'team_2', 'name' => 'Team 2' }
          ]
        }
      }
    end

    before do
      allow(LinearCli::API::Queries::Analytics).to receive(:list_teams).and_return(query)
      allow(client).to receive(:query).with(query).and_return(response)
    end

    it 'fetches teams from the API' do
      teams = data_fetcher.fetch_teams
      expect(teams).to eq(response['teams']['nodes'])
    end

    it 'returns an empty array when the response is empty' do
      allow(client).to receive(:query).with(query).and_return({})
      teams = data_fetcher.fetch_teams
      expect(teams).to eq([])
    end

    it 'returns an empty array when the response nodes are nil' do
      allow(client).to receive(:query).with(query).and_return({ 'teams' => { 'nodes' => nil } })
      teams = data_fetcher.fetch_teams
      expect(teams).to eq([])
    end
  end

  describe '#fetch_projects' do
    let(:query) { 'query Projects' }
    let(:response) do
      {
        'projects' => {
          'nodes' => [
            { 'id' => 'project_1', 'name' => 'Project 1' },
            { 'id' => 'project_2', 'name' => 'Project 2' }
          ]
        }
      }
    end

    before do
      allow(LinearCli::API::Queries::Analytics).to receive(:list_projects).and_return(query)
      allow(client).to receive(:query).with(query).and_return(response)
    end

    it 'fetches projects from the API' do
      projects = data_fetcher.fetch_projects
      expect(projects).to eq(response['projects']['nodes'])
    end

    it 'returns an empty array when the response is empty' do
      allow(client).to receive(:query).with(query).and_return({})
      projects = data_fetcher.fetch_projects
      expect(projects).to eq([])
    end

    it 'returns an empty array when the response nodes are nil' do
      allow(client).to receive(:query).with(query).and_return({ 'projects' => { 'nodes' => nil } })
      projects = data_fetcher.fetch_projects
      expect(projects).to eq([])
    end
  end

  describe '#fetch_issues' do
    let(:query) { 'query {' }
    let(:response) do
      {
        'issues' => {
          'nodes' => [
            { 'id' => 'issue_1', 'title' => 'Issue 1' },
            { 'id' => 'issue_2', 'title' => 'Issue 2' }
          ]
        }
      }
    end

    before do
      allow(LinearCli::API::Queries::Analytics).to receive(:list_issues).and_return(query)
      allow(client).to receive(:query).with(query).and_return(response)
    end

    it 'fetches issues from the API' do
      issues = data_fetcher.fetch_issues
      expect(issues).to eq(response['issues']['nodes'])
    end

    it 'returns an empty array when the response is empty' do
      allow(client).to receive(:query).with(query).and_return({})
      issues = data_fetcher.fetch_issues
      expect(issues).to eq([])
    end

    it 'returns an empty array when the response nodes are nil' do
      allow(client).to receive(:query).with(query).and_return({ 'issues' => { 'nodes' => nil } })
      issues = data_fetcher.fetch_issues
      expect(issues).to eq([])
    end
  end
end
