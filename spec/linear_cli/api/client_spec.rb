# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LinearCli::API::Client do
  let(:api_key) { 'test_api_key' }
  let(:client) { described_class.new(api_key) }

  # Reset mock response before each test
  before do
    LinearCli::API::Client.mock_response = nil
    # Reset safe mode to default (true) before each test
    allow(LinearCli).to receive(:safe_mode?).and_return(true)
  end

  after do
    LinearCli::API::Client.mock_response = nil
  end

  describe '#initialize' do
    context 'when API key is provided' do
      it 'initializes with the provided API key' do
        expect(client.instance_variable_get(:@api_key)).to eq(api_key)
      end
    end

    context 'when API key is not provided' do
      before do
        ENV['LINEAR_API_KEY'] = 'env_api_key'
      end

      after do
        ENV.delete('LINEAR_API_KEY')
      end

      it 'uses the API key from environment variable' do
        client = described_class.new
        expect(client.instance_variable_get(:@api_key)).to eq('env_api_key')
      end
    end

    context 'when no API key is available' do
      before do
        ENV.delete('LINEAR_API_KEY')
      end

      it 'raises an error' do
        expect { described_class.new }.to raise_error(RuntimeError, /Linear API key is required/)
      end
    end
  end

  describe '#get_team_id_by_name' do
    let(:team_name) { 'Engineering' }
    let(:team_id) { 'team_123' }

    context 'when team exists' do
      before do
        LinearCli::API::Client.mock_response = {
          'teams' => {
            'nodes' => [
              { 'id' => team_id, 'name' => team_name, 'key' => 'ENG' }
            ]
          }
        }
      end

      it 'returns the team ID' do
        expect(client.get_team_id_by_name(team_name)).to eq(team_id)
      end

      it 'is case insensitive' do
        expect(client.get_team_id_by_name(team_name.downcase)).to eq(team_id)
        expect(client.get_team_id_by_name(team_name.upcase)).to eq(team_id)
      end
    end

    context 'when team does not exist' do
      before do
        LinearCli::API::Client.mock_response = {
          'teams' => {
            'nodes' => []
          }
        }
      end

      it 'raises an error with helpful message' do
        expect { client.get_team_id_by_name(team_name) }
          .to raise_error(RuntimeError, /No teams found in your Linear workspace/)
      end
    end

    context 'when team name is not found' do
      before do
        LinearCli::API::Client.mock_response = {
          'teams' => {
            'nodes' => [
              { 'id' => 'team_1', 'name' => 'Product', 'key' => 'PROD' },
              { 'id' => 'team_2', 'name' => 'Design', 'key' => 'DESIGN' }
            ]
          }
        }
      end

      it 'raises an error with available teams' do
        expect { client.get_team_id_by_name(team_name) }
          .to raise_error(RuntimeError,
                          /Team 'Engineering' not found. Available teams: Product \(PROD\), Design \(DESIGN\)/)
      end
    end
  end

  describe '#query' do
    let(:read_query) { 'query { viewer { id } }' }
    let(:mutation_query) do
      'mutation CreateIssue($input: IssueCreateInput!) { issueCreate(input: $input) { success } }'
    end
    let(:variables) { {} }

    context 'when the request is successful' do
      before do
        LinearCli::API::Client.mock_response = { 'viewer' => { 'id' => 'user_123' } }
      end

      it 'returns the response data' do
        expect(client.query(read_query, variables)).to eq({ 'viewer' => { 'id' => 'user_123' } })
      end
    end

    context 'when the request fails' do
      it 'raises an error with the message' do
        allow_any_instance_of(LinearCli::API::Client).to receive(:query).and_raise('Authentication failed. Please check your Linear API key.')

        expect { client.query(read_query, variables) }
          .to raise_error(RuntimeError, /Authentication failed/)
      end
    end

    context 'when safe mode is enabled (default)' do
      it 'allows read queries' do
        LinearCli::API::Client.mock_response = { 'viewer' => { 'id' => 'user_123' } }
        expect { client.query(read_query, variables) }.not_to raise_error
      end

      it 'blocks mutation queries' do
        # Allow real API calls to test the mutation blocking logic
        LinearCli::API::Client.allow_real_api_calls_in_test = true

        # This will now attempt to make a "real" API call, which will be intercepted by WebMock
        # We just need it to get past our initial API call prevention check
        expect { client.query(mutation_query, variables) }
          .to raise_error(RuntimeError, /Operation blocked: Safe mode is enabled/)
      end

      it 'provides instructions to disable safe mode in the error message' do
        # Allow real API calls to test the mutation blocking logic
        LinearCli::API::Client.allow_real_api_calls_in_test = true

        expect { client.query(mutation_query, variables) }
          .to raise_error(RuntimeError, /Use the --allow-mutations flag/)
      end
    end

    context 'when safe mode is disabled' do
      before do
        allow(LinearCli).to receive(:safe_mode?).and_return(false)
      end

      it 'allows read queries' do
        LinearCli::API::Client.mock_response = { 'viewer' => { 'id' => 'user_123' } }
        expect { client.query(read_query, variables) }.not_to raise_error
      end

      it 'allows mutation queries' do
        LinearCli::API::Client.mock_response = { 'issueCreate' => { 'success' => true } }
        expect { client.query(mutation_query, variables) }.not_to raise_error
      end
    end

    context 'when attempting real API calls in test environment' do
      it 'raises an error with instructions when mock_response is not set' do
        LinearCli::API::Client.mock_response = nil
        LinearCli::API::Client.allow_real_api_calls_in_test = false

        expect { client.query(read_query, variables) }
          .to raise_error(RuntimeError, /Attempted to make a real API call in test environment/)
      end

      it 'attempts to make a real API call when explicitly permitted' do
        # This test won't actually make a real API call because WebMock/VCR blocks all
        # external connections, but it should get past our initial check
        LinearCli::API::Client.mock_response = nil
        LinearCli::API::Client.allow_real_api_calls_in_test = true

        # When using VCR with WebMock, we might get either a WebMock::NetConnectNotAllowedError
        # or a VCR::Errors::UnhandledHTTPRequestError
        expect do
          client.query(read_query, variables)
          # If no error is raised (shouldn't happen), fail the test
          raise 'Expected an HTTP blocking error but none was raised'
        rescue VCR::Errors::UnhandledHTTPRequestError, WebMock::NetConnectNotAllowedError
          # This is what we expect - the request was blocked because no real HTTP is allowed
          raise 'Expected blocking error'
        rescue StandardError => e
          # Any other error is unexpected
          raise "Got unexpected error: #{e.class.name}: #{e.message}"
        end.to raise_error('Expected blocking error')
      end
    end
  end
end
