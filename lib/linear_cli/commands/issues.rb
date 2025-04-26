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
        variables = { first: options[:limit] }
        
        # Add team filter if provided
        if options[:team]
          # TODO: Implement resolving team name to ID
          variables[:teamId] = options[:team]
        end
        
        # Add assignee filter if provided
        if options[:assignee]
          # TODO: Implement resolving assignee name/email to ID
          variables[:assigneeId] = options[:assignee]
        end
        
        # Add status filter if provided
        if options[:status]
          # TODO: Implement resolving status name to ID
          variables[:states] = [options[:status]]
        end
        
        # Execute the query
        result = client.query(LinearCli::API::Queries::Issues.list_issues, variables)
        issues = result['issues']['nodes']
        
        if issues.empty?
          puts "No issues found matching your criteria."
          return
        end
        
        # Create a table for display
        table = TTY::Table.new(
          header: ['ID', 'Title', 'Status', 'Assignee', 'Team'],
          rows: issues.map do |issue|
            [
              issue['identifier'],
              issue['title'],
              issue['state']['name'],
              issue['assignee'] ? issue['assignee']['name'] : 'Unassigned',
              issue['team']['name']
            ]
          end
        )
        
        pastel = Pastel.new
        puts pastel.bold("Linear Issues (#{issues.size}):")
        puts table.render(:unicode, padding: [0, 1, 0, 1])
      end
      
      desc 'view ID', 'View details of a specific issue'
      def view(id)
        client = LinearCli::API::Client.new
        
        # Execute the query
        result = client.query(LinearCli::API::Queries::Issues.get_issue, { id: id })
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
        
        if issue['comments'] && !issue['comments']['nodes'].empty?
          puts "\nComments:"
          issue['comments']['nodes'].each do |comment|
            puts "#{comment['user']['name']} at #{comment['createdAt']}"
            puts comment['body']
            puts '---'
          end
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
        
        # Build input for the mutation
        input = {
          title: options[:title],
          teamId: options[:team], # TODO: Implement resolving team name to ID
          description: options[:description]
        }
        
        # Add assignee if provided
        if options[:assignee]
          input[:assigneeId] = options[:assignee] # TODO: Implement resolving assignee name/email to ID
        end
        
        # Add status if provided
        if options[:status]
          input[:stateId] = options[:status] # TODO: Implement resolving status name to ID
        end
        
        # Add priority if provided
        if options[:priority]
          input[:priority] = options[:priority].to_i
        end
        
        # Add labels if provided
        if options[:labels]
          input[:labelIds] = options[:labels] # TODO: Implement resolving label names to IDs
        end
        
        # Execute the mutation
        result = client.query(LinearCli::API::Queries::Issues.create_issue, { input: input })
        
        if result['issueCreate']['success']
          issue = result['issueCreate']['issue']
          puts "Issue created successfully: #{issue['identifier']} - #{issue['title']}"
          puts "URL: #{issue['url']}"
        else
          puts "Failed to create issue."
        end
      end
      
      desc 'update ID', 'Update an existing issue'
      option :title, type: :string, desc: 'Issue title'
      option :description, type: :string, desc: 'Issue description'
      option :assignee, type: :string, desc: 'Assignee email or name'
      option :status, type: :string, desc: 'Status name'
      option :priority, type: :numeric, desc: 'Priority (0-4)'
      def update(id)
        client = LinearCli::API::Client.new
        
        # Build input for the mutation
        input = {}
        
        input[:title] = options[:title] if options[:title]
        input[:description] = options[:description] if options[:description]
        
        # Add assignee if provided
        if options[:assignee]
          input[:assigneeId] = options[:assignee] # TODO: Implement resolving assignee name/email to ID
        end
        
        # Add status if provided
        if options[:status]
          input[:stateId] = options[:status] # TODO: Implement resolving status name to ID
        end
        
        # Add priority if provided
        if options[:priority]
          input[:priority] = options[:priority].to_i
        end
        
        if input.empty?
          puts "No update parameters provided."
          return
        end
        
        # Execute the mutation
        result = client.query(LinearCli::API::Queries::Issues.update_issue, { id: id, input: input })
        
        if result['issueUpdate']['success']
          issue = result['issueUpdate']['issue']
          puts "Issue updated successfully: #{issue['identifier']} - #{issue['title']}"
          puts "URL: #{issue['url']}"
        else
          puts "Failed to update issue."
        end
      end
      
      desc 'comment ID BODY', 'Add a comment to an issue'
      def comment(id, body)
        client = LinearCli::API::Client.new
        
        # Execute the mutation
        result = client.query(LinearCli::API::Queries::Issues.create_comment, { issueId: id, body: body })
        
        if result['commentCreate']['success']
          puts "Comment added successfully."
        else
          puts "Failed to add comment."
        end
      end
    end
  end
end 