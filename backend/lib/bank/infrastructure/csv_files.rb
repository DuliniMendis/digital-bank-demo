# frozen_string_literal: true

require 'csv'

module Bank
  module Infrastructure
    # The file is not readable as CSV at all (for example an unclosed quote).
    class UnreadableCsv < StandardError; end

    # CsvFiles is the only code that knows the input arrives as CSV.
    #
    # It splits the text into lines and columns and hands each line to the
    # use cases as plain text. It does not check account numbers or
    # amounts; the domain does that.
    #
    # The files have no header row. Blank lines are skipped.
    module CsvFiles
      # Balances file: account number, balance.
      def self.opening_balances(text)
        rows(text).map do |line, fields|
          UseCases::OpeningBalance.new(line: line, number: fields[0], balance: fields[1])
        end
      end

      # Transfers file: from account, to account, amount.
      def self.transfer_requests(text)
        rows(text).map do |line, fields|
          UseCases::TransferRequest.new(line: line, from: fields[0], to: fields[1], amount: fields[2])
        end
      end

      # Returns [line number, columns] for every line that is not blank.
      def self.rows(text)
        lines = CSV.parse(text, skip_blanks: false)
        numbered = lines.each_with_index.map { |fields, index| [index + 1, fields] }
        numbered.reject { |_line, fields| fields.compact.empty? }
      rescue CSV::MalformedCSVError => e
        raise UnreadableCsv, e.message
      end
      private_class_method :rows
    end
  end
end
