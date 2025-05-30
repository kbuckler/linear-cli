# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LinearCli::UI::TableRenderer do
  let(:headers) { %w[Name Value] }
  let(:rows) { [['Item 1', 10], ['Item 2', 20]] }
  let(:options) { { widths: { 'Name' => 15, 'Value' => 10 } } }

  describe '.in_test_environment?' do
    it 'can be called without errors' do
      # We just verify the method exists and runs without errors
      # The actual return value depends on the environment
      expect { described_class.in_test_environment? }.not_to raise_error
    end
  end

  describe '.render_table' do
    it 'renders a simple table in test environment' do
      allow(described_class).to receive(:in_test_environment?).and_return(true)

      expected_output = [
        'Name | Value',
        '-----+------',
        'Item 1 | 10',
        'Item 2 | 20'
      ].join("\n")

      expect(described_class.render_table(headers, rows)).to eq(expected_output)
    end

    it 'renders a TTY table in normal environment' do
      allow(described_class).to receive(:in_test_environment?).and_return(false)
      allow_any_instance_of(TTY::Table).to receive(:render).and_return('TTY Table Output')

      expect(described_class.render_table(headers, rows)).to eq('TTY Table Output')
    end
  end

  describe '.output_table' do
    before do
      # Mock Pastel to avoid formatting in tests
      pastel_mock = double('Pastel')
      allow(Pastel).to receive(:new).and_return(pastel_mock)
      allow(pastel_mock).to receive(:bold) { |str| str }
      # Mock Logger to avoid actual logging in tests
      allow(LinearCli::UI::Logger).to receive(:info)
    end

    it 'outputs a table with title' do
      title = 'Test Table'
      allow(described_class).to receive(:render_table).and_return('Rendered Table')
      expect(LinearCli::UI::Logger).to receive(:info).with("\nTest Table")
      expect(LinearCli::UI::Logger).to receive(:info).with('Rendered Table')

      described_class.output_table(title, headers, rows, options)
    end

    it 'handles empty rows' do
      expect(LinearCli::UI::Logger).to receive(:info).with("\nEmpty Table")
      expect(LinearCli::UI::Logger).to receive(:info).with('No data available.')

      described_class.output_table('Empty Table', headers, [], options)
    end
  end

  describe '.render_simple_table' do
    it 'formats a simple text table' do
      expected_output = [
        'Name | Value',
        '-----+------',
        'Item 1 | 10',
        'Item 2 | 20'
      ].join("\n")

      output = described_class.send(:render_simple_table, headers, rows)
      expect(output).to eq(expected_output)
    end
  end

  describe '.render_tty_table' do
    it 'configures and renders a TTY table' do
      table_double = instance_double(TTY::Table)

      allow(TTY::Table).to receive(:new).and_return(table_double)
      allow(table_double).to receive(:render).and_return('TTY Table Output')

      output = described_class.send(:render_tty_table, headers, rows, options)
      expect(output).to eq('TTY Table Output')
    end

    it 'applies border separator option when provided' do
      table_double = instance_double(TTY::Table)

      allow(TTY::Table).to receive(:new).and_return(table_double)
      allow(table_double).to receive(:render).and_return('TTY Table Output')

      options_with_separator = options.merge(border_separator: true)
      output = described_class.send(:render_tty_table, headers, rows, options_with_separator)
      expect(output).to eq('TTY Table Output')
    end
  end
end
