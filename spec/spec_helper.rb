require 'bundler/setup'
require 'linear_cli'
require 'webmock/rspec'
require 'vcr'

# Configure VCR
VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  
  # Filter out sensitive data
  config.filter_sensitive_data('<LINEAR_API_KEY>') { ENV['LINEAR_API_KEY'] }
  
  # Allow HTTP connections when no cassette is in use
  config.allow_http_connections_when_no_cassette = true
  
  # Ignore localhost requests
  config.ignore_localhost = true
end

# Disable real HTTP connections in tests
WebMock.disable_net_connect!(allow_localhost: true)

# Configure RSpec
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.order = :random
  Kernel.srand config.seed
end 