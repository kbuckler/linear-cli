module LinearCli
  module Services
    module Analytics
      # Service to filter issues by time period
      class PeriodFilter
        # Filter issues by specified time period
        # @param issues [Array<Hash>] Array of issue data
        # @param period [String] Period to filter by ('all', 'month', 'quarter', 'year')
        # @return [Array<Hash>] Filtered issues
        def filter_issues_by_period(issues, period)
          # Handle nil issues
          return [] if issues.nil?

          current_time = Time.now

          if period == 'all'
            # For 'all', get the last 6 months of issues based on completion date or creation date
            six_months_ago = (Time.now - (6 * 30 * 24 * 60 * 60)).strftime('%Y-%m-%d')

            issues.select do |issue|
              # Use completedAt if available, otherwise fall back to createdAt
              date_to_check = issue['completedAt'] || issue['createdAt']
              next false unless date_to_check

              date_to_check >= six_months_ago
            end
          else
            issues.select do |issue|
              # Use completedAt if available, otherwise fall back to createdAt
              date_to_check = issue['completedAt'] || issue['createdAt']
              next false unless date_to_check

              date_time = Time.parse(date_to_check)

              case period
              when 'month'
                same_month_and_year?(date_time, current_time)
              when 'quarter'
                same_quarter_and_year?(date_time, current_time)
              when 'year'
                same_year?(date_time, current_time)
              else
                true
              end
            end
          end
        end

        private

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
          time1.year == time2.year && ((time1.month - 1) / 3) == ((time2.month - 1) / 3)
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
