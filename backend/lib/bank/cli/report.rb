# frozen_string_literal: true

module Bank
  class CLI
    # Report turns the final accounts and the transfer results into the
    # text that the command prints.
    class Report
      def initialize(accounts:, results:)
        @accounts = accounts
        @results = results
      end

      def to_s
        [balances_section, summary_line, rejected_section].compact.join("\n\n")
      end

      private

      def balances_section
        lines = @accounts.map do |account|
          "  #{account.number}  #{account.balance.to_s.rjust(12)}"
        end
        ['Final balances', *lines].join("\n")
      end

      def summary_line
        "Transfers: #{completed.size} completed, #{rejected.size} rejected"
      end

      # Left out of the report entirely when nothing was rejected.
      def rejected_section
        return nil if rejected.empty?

        lines = rejected.map { |result| rejected_line(result) }
        ['Rejected transfers', *lines].join("\n")
      end

      def rejected_line(result)
        request = result.request
        "  line #{request.line}: #{request.from} -> #{request.to} " \
          "#{request.amount}: #{result.rejection_reason}"
      end

      def completed
        @results.select(&:completed?)
      end

      def rejected
        @results.reject(&:completed?)
      end
    end
  end
end
