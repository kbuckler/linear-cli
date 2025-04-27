module LinearCli
  module Services
    module Analytics
      # Service to filter issues by time period
      class PeriodFilter
        # Number of months to look back for 'all' period
        MONTHS_LOOKBACK = 6

        # Filter issues by specified time period
        # @param issues [Array<Hash>] Array of issue data
        # @param period [String] Period to filter by ('all', 'month', 'quarter', 'year')
        # @return [Array<Hash>] Filtered issues
        def filter_issues_by_period(issues, period)
          # Handle nil issues
          return [] if issues.nil? || issues.empty?

          current_time = Time.now

          case period
          when 'all'
            filter_by_lookback_period(issues, current_time)
          when 'month', 'quarter', 'year'
            filter_by_relative_period(issues, period, current_time)
          else
            # Default behavior for unknown periods is to return all issues
            issues
          end
        end

        private

        # Filter issues by lookback period (last N months)
        # @param issues [Array<Hash>] Issues to filter
        # @param current_time [Time] Current time reference
        # @return [Array<Hash>] Filtered issues
        def filter_by_lookback_period(issues, current_time)
          cutoff_date = calculate_cutoff_date(current_time)

          issues.select do |issue|
            date_to_check = extract_date_to_check(issue)
            next false unless date_to_check

            date_to_check >= cutoff_date
          end
        end

        # Filter issues by a relative period (month, quarter, year)
        # @param issues [Array<Hash>] Issues to filter
        # @param period [String] Period type ('month', 'quarter', 'year')
        # @param current_time [Time] Current time reference
        # @return [Array<Hash>] Filtered issues
        def filter_by_relative_period(issues, period, current_time)
          issues.select do |issue|
            date_string = extract_date_to_check(issue)
            next false unless date_string

            begin
              date_time = Time.parse(date_string)

              case period
              when 'month'
                same_month_and_year?(date_time, current_time)
              when 'quarter'
                same_quarter_and_year?(date_time, current_time)
              when 'year'
                same_year?(date_time, current_time)
              end
            rescue ArgumentError
              # Handle invalid date format
              Rails.logger.warn("Invalid date format: #{date_string}") if defined?(Rails)
              false
            end
          end
        end

        # Extract the date to check from an issue
        # Prioritizes completedAt over createdAt
        # @param issue [Hash] Issue data
        # @return [String, nil] Date string or nil if not available
        def extract_date_to_check(issue)
          issue['completedAt'] || issue['createdAt']
        end

        # Calculate cutoff date for lookback period
        # @param current_time [Time] Current time reference
        # @return [String] Cutoff date in YYYY-MM-DD format
        def calculate_cutoff_date(current_time)
          # Calculate exactly N months ago using Date arithmetic for accuracy
          require 'date' unless defined?(Date)
          date = Date.new(current_time.year, current_time.month, current_time.day)
          months_ago = date << MONTHS_LOOKBACK
          months_ago.strftime('%Y-%m-%d')
        end

        # Check if two dates are in the same month and year
        # @param time1 [Time] First time to compare
        # @param time2 [Time] Second time to compare
        # @return [Boolean] Whether the two times are in the same month and year
        def same_month_and_year?(time1, time2)
          time1.year == time2.year && time1.month == time2.month
        end

        # Check if two dates are in the same quarter and year
        # @param time1 [Time] First time to compare
        # @param time2 [Time] Second time to compare
        # @return [Boolean] Whether the two times are in the same quarter and year
        def same_quarter_and_year?(time1, time2)
          time1.year == time2.year && quarter_from_month(time1.month) == quarter_from_month(time2.month)
        end

        # Get quarter (1-4) from month (1-12)
        # @param month [Integer] Month number (1-12)
        # @return [Integer] Quarter number (1-4)
        def quarter_from_month(month)
          ((month - 1) / 3) + 1
        end

        # Check if two dates are in the same year
        # @param time1 [Time] First time to compare
        # @param time2 [Time] Second time to compare
        # @return [Boolean] Whether the two times are in the same year
        def same_year?(time1, time2)
          time1.year == time2.year
        end
      end
    end
  end
end
