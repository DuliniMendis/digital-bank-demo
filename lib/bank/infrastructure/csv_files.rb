# frozen_string_literal: true

require 'csv'

module Bank
  module Infrastructure
    # Reads the two CSV files. A header row is optional, and blank lines are
    # skipped. The fields are passed on as plain text, because checking that
    # they are valid is the job of the domain.
    module CsvFiles
      BYTE_ORDER_MARK = "\uFEFF"

      # Each line of the balances file is: account number, balance.
      def self.opening_balances(text)
        rows(text, columns: 2).map do |line, fields|
          Application::OpeningBalance.new(line: line, number: fields[0], balance: fields[1])
        end
      end

      # Each line of the transfers file is: from account, to account, amount.
      def self.transfer_requests(text)
        rows(text, columns: 3).map do |line, fields|
          Application::TransferRequest.new(line: line, from: fields[0], to: fields[1], amount: fields[2])
        end
      end

      # Returns [line number, fields] for every line of data.
      #
      # Blank lines and a header are kept while the lines are numbered
      # (`skip_blanks: false`) and only dropped afterwards. That way the
      # numbers match the original file, and an error message can point at
      # the right line.
      def self.rows(text, columns:)
        lines = CSV.parse(as_utf8(text), skip_blanks: false)
        numbered = lines.each_with_index.map { |fields, index| [index + 1, fields] }
        rows = numbered.reject { |_line, fields| fields.compact.empty? }
        rows.each { |line, fields| refuse_extra_columns(line, fields, columns) }
        header?(rows.first) ? rows.drop(1) : rows
      end

      # A comma inside an amount, as in 1,000.00, makes it look like two
      # columns, and reading only the first of them would move $1. Nothing
      # in the line says which column was meant, so the whole file is
      # refused here, before any line of it is used.
      def self.refuse_extra_columns(line, fields, expected)
        return if fields.size <= expected

        raise CSV::MalformedCSVError.new("Expected #{expected} columns but found #{fields.size}", line)
      end

      # Every line of data starts with an account number, so a first line
      # that starts with a word and has no digits in it is taken to be a
      # header. A mistyped account number still has digits in it, so it is
      # kept and reported as a bad line instead of being quietly skipped.
      def self.header?(row)
        first_field = row&.last&.first.to_s.strip
        !first_field.empty? && !first_field.match?(/\d/)
      end

      # An uploaded file arrives as raw bytes, with nothing to say which
      # encoding they are in. This reads them as UTF-8 and replaces any byte
      # that is not valid UTF-8 with a placeholder character, so a stray byte
      # spoils one field and not the whole file.
      #
      # Spreadsheet programs often start a file with an invisible byte-order
      # mark. It is removed here, because otherwise it would become part of
      # the first account number.
      def self.as_utf8(text)
        text.dup.force_encoding(Encoding::UTF_8).scrub.delete_prefix(BYTE_ORDER_MARK)
      end
      private_class_method :rows, :refuse_extra_columns, :header?, :as_utf8
    end
  end
end
