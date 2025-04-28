# frozen_string_literal: true

require_relative 'lib/linear_cli/version'

Gem::Specification.new do |spec|
  spec.name          = 'linear-cli'
  spec.version       = LinearCli::VERSION
  spec.authors       = ['Kenny Buckler']
  spec.email         = ['kbuckler@gmail.com']

  spec.summary       = 'Command-line interface for Linear issue tracking'
  spec.description   = 'A Ruby CLI tool that allows AI assistants ' \
                       'and humans to interact with the Linear issue ' \
                       'tracking system'
  spec.homepage      = 'https://github.com/kbuckler/linear-cli'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob('{bin,lib}/**/*') + %w[README.md LICENSE]
  spec.bindir        = 'bin'
  spec.executables   = ['linear']
  spec.require_paths = ['lib']

  # Dependencies
  spec.add_dependency 'dotenv', '~> 2.8'
  spec.add_dependency 'httparty', '~> 0.21.0'
  spec.add_dependency 'pastel', '~> 0.8.0'
  spec.add_dependency 'thor', '~> 1.2'
  spec.add_dependency 'tty-spinner', '~> 0.9.3'
  spec.add_dependency 'tty-table', '~> 0.12.0'
  spec.add_dependency 'yaml', '~> 0.2.0'

  # Development dependencies are specified in the Gemfile
  spec.metadata['rubygems_mfa_required'] = 'true'
end
