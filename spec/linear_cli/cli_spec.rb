# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LinearCli::CLI do
  describe 'safe mode' do
    context 'when allow_mutations is enabled via command line' do
      it 'disables the global safe mode flag' do
        # Save original safe mode to restore after test
        original_safe_mode = LinearCli.safe_mode?

        begin
          # Create CLI instance with allow_mutations flag
          described_class.new([], { allow_mutations: true })

          # Verify that safe mode is disabled
          expect(LinearCli.safe_mode?).to eq(false)
        ensure
          # Restore original safe mode
          LinearCli.instance_variable_set(:@safe_mode, original_safe_mode)
        end
      end
    end

    context 'when allow_mutations is not specified' do
      it 'keeps the global safe mode flag as true (default)' do
        # Save original safe mode to restore after test
        original_safe_mode = LinearCli.safe_mode?

        begin
          # Create CLI instance without allow_mutations flag
          described_class.new

          # Verify that safe mode is enabled
          expect(LinearCli.safe_mode?).to eq(true)
        ensure
          # Restore original safe mode
          LinearCli.instance_variable_set(:@safe_mode, original_safe_mode)
        end
      end
    end
  end
end
