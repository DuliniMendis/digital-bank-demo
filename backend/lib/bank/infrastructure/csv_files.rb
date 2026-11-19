# frozen_string_literal: true

require 'csv'

module Bank
  module Infrastructure
    # Reads the two CSV files. A header row is optional, and blank lines are
    # skipped. The fields are passed on as plain text, because checking that
    # they are valid is the job of the domain.
    module CsvFiles
      # Each line of the balances file is: account number, balance.
      def self.opening_balances(text)
        rows(text).map do |line, fields|
          UseCases::OpeningBalance.new(line: line, number: fields[0], balance: fields[1])
        end
      end

      # Each line of the transfers file is: from account, to account, amount.
      def self.transfer_requests(text)
        rows(text).map do |line, fields|
          UseCases::TransferRequest.new(line: line, from: fields[0], to: fields[1], amount: fields[2])
        end
      end

      # Returns [line number, fields] for every line of data.
      #
      # Blank lines and a header are kept while the lines are numbered
      # (`skip_blanks: false`) and only dropped afterwards. That way the
      # numbers match the original file, and an error message can point at
      # the right line.
      def self.rows(text)
        lines = CSV.parse(text, skip_blanks: false)
        numbered = lines.each_with_index.map { |fields, index| [index + 1, fields] }
        rows = numbered.reject { |_line, fields| fields.compact.empty? }
        header?(rows.first) ? rows.drop(1) : rows
      end

      # Every line of data starts with an account number, so a first line
      # that starts with a word and has no digits in it is taken to be a
      # header. A mistyped account number still has digits in it, so it is
      # kept and reported as a bad line instead of being quietly skipped.
      def self.header?(row)
        first_field = row&.last&.first.to_s.strip
        !first_field.empty? && !first_field.match?(/\d/)
      end
      private_class_method :rows, :header?
    end
  end
end
