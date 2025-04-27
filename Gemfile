# frozen_string_literal: true

source 'https://rubygems.org'

# CLI framework
gem 'thor', '~> 1.2'

# HTTP client
gem 'httparty', '~> 0.21.0'

# Environment variables
gem 'dotenv', '~> 2.8'

# Pretty terminal output
gem 'colorize', '~> 1.1'
gem 'pastel', '~> 0.8.0'
gem 'terminal-table', '~> 3.0'
gem 'tty-spinner', '~> 0.9.3'
gem 'tty-table', '~> 0.12.0'

# For handling configuration
gem 'yaml', '~> 0.2.0'

# CSV support (required for tty-table)
gem 'csv', '~> 3.2'

# Ruby Active Support
gem 'activesupport', '~> 7.0'

group :development, :test do
  # Testing
  gem 'bundler', '~> 2.0'
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.12'
  gem 'vcr', '~> 6.1'
  gem 'webmock', '~> 3.18'

  # Linting and formatting
  gem 'rubocop', '~> 1.50', require: false

  # Documentation
  gem 'yard', '~> 0.9.34'
end
