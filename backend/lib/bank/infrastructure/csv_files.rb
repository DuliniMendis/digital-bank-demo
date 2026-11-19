# frozen_string_literal: true

require 'csv'

module Bank
  module Infrastructure
    # Reads the two CSV files. Neither has a header row, and blank lines are
    # skipped. Fields are passed on as plain text; validating them is the
    # domain's job.
    module CsvFiles
      # account number, balance
      def self.opening_balances(text)
        rows(text).map do |line, fields|
          UseCases::OpeningBalance.new(line: line, number: fields[0], balance: fields[1])
        end
      end

      # from, to, amount
      def self.transfer_requests(text)
        rows(text).map do |line, fields|
          UseCases::TransferRequest.new(line: line, from: fields[0], to: fields[1], amount: fields[2])
        end
      end

      # Line numbers are kept so an error can point at the right line.
      def self.rows(text)
        lines = CSV.parse(text, skip_blanks: false)
        numbered = lines.each_with_index.map { |fields, index| [index + 1, fields] }
        numbered.reject { |_line, fields| fields.compact.empty? }
      end
      private_class_method :rows
    end
  end
end
