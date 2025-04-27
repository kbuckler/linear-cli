require 'thor'
require 'pastel'
require 'tty-table'

module LinearCli
  module Commands
    # Command group for managing Linear issues
    class Issues < Thor
      package_name 'linear issues'

      desc 'list', 'List Linear issues'
      option :team, type: :string, desc: 'Filter by team name'
      option :assignee, type: :string, desc: 'Filter by assignee email or name'
      option :status, type: :string, desc: 'Filter by status name'
      option :limit, type: :numeric, default: 20, desc: 'Number of issues to fetch'
      def list
        client = LinearCli::API::Client.new

        # Build variables for the query
        variables = { first: options[:limit] ? LinearCli::Validators::InputValidator.validate_limit(options[:limit]) : 20 }

        # Add team filter if provided
        if options[:team]
          sanitized_team = LinearCli::Validators::InputValidator.validate_team_name(options[:team])
          team_id = client.get_team_id_by_name(sanitized_team)
          variables[:teamId] = team_id
        end

        # Add assignee filter if provided
        if options[:assignee]
          # TODO: Implement resolving assignee name/email to ID
          sanitized_assignee = LinearCli::Validators::InputValidator.sanitize_string(options[:assignee])
          # If it looks like an email, validate it
          LinearCli::Validators::InputValidator.validate_email(sanitized_assignee) if sanitized_assignee.include?('@')
          variables[:assigneeId] = sanitized_assignee
        end

        # Add status filter if provided
        if options[:status]
          # TODO: Implement resolving status name to ID
          sanitized_status = LinearCli::Validators::InputValidator.sanitize_string(options[:status])
          variables[:states] = [sanitized_status]
        end

        # Execute the query
        result = client.query(LinearCli::API::Queries::Issues.list_issues, variables)
        issues = result['issues']['nodes']

        if issues.empty?
          puts 'No issues found matching your criteria.'
          return
        end

        pastel = Pastel.new
        puts pastel.bold("Linear Issues (#{issues.size}):")

        # Prepare the data
        rows = issues.map do |issue|
          # For detailed view - include priority, estimate, cycle, etc.
          priority_values = { 0 => 'No priority', 1 => 'Urgent', 2 => 'High', 3 => 'Medium', 4 => 'Low' }
          priority = issue['priority'] ? priority_values[issue['priority']] : 'Not set'

          cycle = issue['cycle'] ? issue['cycle']['name'] : 'No cycle'

          labels = if issue['labels'] && issue['labels']['nodes']
                     issue['labels']['nodes'].map { |l| l['name'] }.join(', ')
                   else
                     ''
                   end

          [
            issue['identifier'],
            issue['title'],
            issue['state']['name'],
            issue['assignee'] ? issue['assignee']['name'] : 'Unassigned',
            priority,
            issue['estimate'] || 'Not set',
            cycle,
            labels,
            issue['team']['name']
          ]
        end

        # Use simple output in test environments or when not in a terminal
        if !$stdout.tty? || ENV['RACK_ENV'] == 'test' || ENV['RAILS_ENV'] == 'test'
          puts 'ID | Title | Status | Assignee | Priority | Estimate | Cycle | Labels | Team'
          puts '-' * 80
          rows.each do |row|
            puts row.join(' | ')
          end
        else
          # Create a table for display
          header = %w[ID Title Status Assignee Priority Estimate Cycle Labels Team]

          # Use detailed view with nice formatting
          table = TTY::Table.new(header: header, rows: rows)
          puts table.render(:unicode, resize: false) do |renderer|
            renderer.border.separator = :each_row
            renderer.width = [10, 30, 12, 15, 10, 10, 15, 20, 10]
          end
        end
      end

      desc 'view ID', 'View details of a specific issue'
      def view(id)
        # Validate the issue ID format
        begin
          sanitized_id = LinearCli::Validators::InputValidator.sanitize_string(id)
          # Only validate format if it looks like an ID pattern
          LinearCli::Validators::InputValidator.validate_issue_id(sanitized_id) if sanitized_id.include?('-')
        rescue ArgumentError => e
          puts "Warning: #{e.message}"
          # Continue anyway as the API will validate the ID
        end

        client = LinearCli::API::Client.new

        # Execute the query
        result = client.query(LinearCli::API::Queries::Issues.get_issue, { id: sanitized_id })
        issue = result['issue']

        if issue.nil?
          puts "Issue not found: #{id}"
          return
        end

        pastel = Pastel.new
        puts pastel.bold("#{issue['identifier']}: #{issue['title']}")
        puts "Status: #{issue['state']['name']}"
        puts "Team: #{issue['team']['name']}"
        puts "Assignee: #{issue['assignee'] ? issue['assignee']['name'] : 'Unassigned'}"
        puts "Priority: #{issue['priority'] || 'Not set'}"
        puts "\nDescription:"
        puts issue['description'] || 'No description provided.'

        return unless issue['comments'] && !issue['comments']['nodes'].empty?

        puts "\nComments:"
        issue['comments']['nodes'].each do |comment|
          puts "#{comment['user']['name']} at #{comment['createdAt']}"
          puts comment['body']
          puts '---'
        end
      end

      desc 'create', 'Create a new issue'
      option :title, type: :string, required: true, desc: 'Issue title'
      option :team, type: :string, required: true, desc: 'Team name'
      option :description, type: :string, desc: 'Issue description'
      option :assignee, type: :string, desc: 'Assignee email or name'
      option :status, type: :string, desc: 'Status name'
      option :priority, type: :numeric, desc: 'Priority (0-4)'
      option :labels, type: :array, desc: 'Comma-separated list of label names'
      def create
        client = LinearCli::API::Client.new

        # Validate and sanitize inputs
        begin
          sanitized_title = LinearCli::Validators::InputValidator.validate_title(options[:title])
          sanitized_team = LinearCli::Validators::InputValidator.validate_team_name(options[:team])

          # Get team ID from name
          team_id = client.get_team_id_by_name(sanitized_team)

          # Build input for the mutation
          input = {
            title: sanitized_title,
            teamId: team_id,
            description: LinearCli::Validators::InputValidator.validate_description(options[:description])
          }

          # Add assignee if provided
          if options[:assignee]
            sanitized_assignee = LinearCli::Validators::InputValidator.sanitize_string(options[:assignee])
            # If it looks like an email, validate it
            LinearCli::Validators::InputValidator.validate_email(sanitized_assignee) if sanitized_assignee.include?('@')
            input[:assigneeId] = sanitized_assignee # TODO: Implement resolving assignee name/email to ID
          end

          # Add status if provided
          if options[:status]
            input[:stateId] = LinearCli::Validators::InputValidator.sanitize_string(options[:status]) # TODO: Implement resolving status name to ID
          end

          # Add priority if provided
          if options[:priority]
            LinearCli::Validators::InputValidator.validate_priority(options[:priority])
            input[:priority] = options[:priority].to_i
          end

          # Add labels if provided
          if options[:labels]
            # Sanitize each label name
            sanitized_labels = options[:labels].map do |label|
              LinearCli::Validators::InputValidator.sanitize_string(label)
            end
            input[:labelIds] = sanitized_labels # TODO: Implement resolving label names to IDs
          end

          # Execute the mutation
          result = client.query(LinearCli::API::Queries::Issues.create_issue, { input: input })

          if result['issueCreate'] && result['issueCreate']['success']
            issue = result['issueCreate']['issue']
            puts "Issue created successfully: #{issue['identifier']} - #{issue['title']}"
            puts "URL: #{issue['url']}"
          else
            puts 'Failed to create issue.'
          end
        rescue ArgumentError => e
          puts "Error: #{e.message}"
        end
      end

      desc 'update ID', 'Update an existing issue'
      option :title, type: :string, desc: 'Issue title'
      option :description, type: :string, desc: 'Issue description'
      option :assignee, type: :string, desc: 'Assignee email or name'
      option :status, type: :string, desc: 'Status name'
      option :priority, type: :numeric, desc: 'Priority (0-4)'
      def update(id)
        # Validate and sanitize issue ID
        sanitized_id = LinearCli::Validators::InputValidator.sanitize_string(id)
        # Only validate format if it looks like an ID pattern
        LinearCli::Validators::InputValidator.validate_issue_id(sanitized_id) if sanitized_id.include?('-')

        client = LinearCli::API::Client.new

        # Build input for the mutation
        input = {}

        # Validate and add title if provided
        input[:title] = LinearCli::Validators::InputValidator.validate_title(options[:title]) if options[:title]

        # Validate and add description if provided
        if options[:description]
          input[:description] = LinearCli::Validators::InputValidator.validate_description(options[:description])
        end

        # Add assignee if provided
        if options[:assignee]
          sanitized_assignee = LinearCli::Validators::InputValidator.sanitize_string(options[:assignee])
          # If it looks like an email, validate it
          LinearCli::Validators::InputValidator.validate_email(sanitized_assignee) if sanitized_assignee.include?('@')
          input[:assigneeId] = sanitized_assignee # TODO: Implement resolving assignee name/email to ID
        end

        # Add status if provided
        if options[:status]
          input[:stateId] = LinearCli::Validators::InputValidator.sanitize_string(options[:status]) # TODO: Implement resolving status name to ID
        end

        # Add priority if provided
        if options[:priority]
          LinearCli::Validators::InputValidator.validate_priority(options[:priority])
          input[:priority] = options[:priority].to_i
        end

        if input.empty?
          puts 'No update parameters provided.'
          return
        end

        # Execute the mutation
        result = client.query(LinearCli::API::Queries::Issues.update_issue, { id: sanitized_id, input: input })

        if result['issueUpdate'] && result['issueUpdate']['success']
          issue = result['issueUpdate']['issue']
          puts "Issue updated successfully: #{issue['identifier']} - #{issue['title']}"
          puts "URL: #{issue['url']}"
        else
          puts 'Failed to update issue.'
        end
      rescue ArgumentError => e
        puts "Error: #{e.message}"
      end

      desc 'comment ID BODY', 'Add a comment to an issue'
      long_desc <<-LONGDESC
        Add a comment to a Linear issue.

        Examples:
          linear issues comment KBU-10 "This is my comment"
          linear issues comment KBU-10 This is also a valid comment

        The comment text can include spaces without needing quotes.
      LONGDESC
      def comment(issue_identifier, *comment_parts)
        # Validate and sanitize issue ID
        sanitized_id = LinearCli::Validators::InputValidator.sanitize_string(issue_identifier)
        # Only validate format if it looks like an ID pattern
        LinearCli::Validators::InputValidator.validate_issue_id(sanitized_id) if sanitized_id.include?('-')

        client = LinearCli::API::Client.new

        # Join all the parts to form the full comment body
        body = comment_parts.join(' ')

        # Validate and sanitize comment body
        sanitized_body = LinearCli::Validators::InputValidator.validate_comment_body(body)

        # Just use the issue identifier directly
        # Linear API will validate and return an error if the issue doesn't exist
        comment_result = client.query(LinearCli::API::Queries::Issues.create_comment, {
                                        issueId: sanitized_id.upcase,
                                        body: sanitized_body
                                      })

        if comment_result['commentCreate'] && comment_result['commentCreate']['success']
          puts "Comment added successfully to #{sanitized_id.upcase}"
        else
          puts 'Failed to add comment.'
        end
      rescue ArgumentError => e
        puts "Error: #{e.message}"
      rescue RuntimeError => e
        puts "Error: #{e.message}"
      end
    end
  end
end
