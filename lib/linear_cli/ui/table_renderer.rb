# frozen_string_literal: true

require 'tty-table'
require 'pastel'
require_relative 'logger'

module LinearCli
  module UI
    # Central module for TTY table rendering with consistent styling
    module TableRenderer
      # Check if running in test environment
      # @return [Boolean] True if running in test environment
      def self.in_test_environment?
        defined?(RSpec) || ENV['RACK_ENV'] == 'test' ||
          ENV['RAILS_ENV'] == 'test' || !$stdout.tty?
      end

      # Renders a TTY table with consistent styling
      # @param headers [Array<String>] Table headers
      # @param rows [Array<Array>] Table data rows
      # @param options [Hash] Additional rendering options
      # @option options [Hash] :widths Column widths mapping header to width
      # @option options [Boolean] :border_separator Add row separators
      # @return [String] Rendered table
      def self.render_table(headers, rows, options = {})
        if in_test_environment?
          render_simple_table(headers, rows)
        else
          render_tty_table(headers, rows, options)
        end
      end

      # Directly output a table with a title
      # @param title [String] Table title
      # @param headers [Array<String>] Table headers
      # @param rows [Array<Array>] Table data rows
      # @param options [Hash] Additional rendering options
      # @return [void]
      def self.output_table(title, headers, rows, options = {})
        pastel = Pastel.new
        LinearCli::UI::Logger.info("\n#{pastel.bold(title)}") if title

        if rows.empty?
          LinearCli::UI::Logger.info('No data available.')
          return
        end

        LinearCli::UI::Logger.info(render_table(headers, rows, options))
      end

      # Renders a simple text table for test environments
      # @param headers [Array<String>] Table headers
      # @param rows [Array<Array>] Table data rows
      # @return [String] Rendered simple table
      def self.render_simple_table(headers, rows)
        output = []
        output << headers.join(' | ')
        output << headers.map { |h| '-' * h.length }.join('-+-')
        rows.each do |row|
          output << row.join(' | ')
        end
        output.join("\n")
      end

      # Renders a TTY table with consistent styling
      # @param headers [Array<String>] Table headers
      # @param rows [Array<Array>] Table data rows
      # @param options [Hash] Additional rendering options
      # @return [String] Rendered TTY table
      def self.render_tty_table(headers, rows, options = {})
        table = TTY::Table.new(header: headers, rows: rows)

        # Set rendering options
        renderer_options = {
          resize: false,
          padding: [0, 1, 0, 1]
        }

        # Add border separator if requested
        if options[:border_separator]
          renderer_options[:border] =
            { separator: :each_row }
        end

        # Render the table with consistent styling
        table.render(renderer_options)
      end
    end
  end
end
