# frozen_string_literal: true

module Bank
  module UseCases
    # One line of the balances file: its line number and the two fields as
    # plain text. Nothing has been validated at this point.
    OpeningBalance = Data.define(:line, :number, :balance)

    # Raised when a line of the balances file is rejected. The message starts
    # with the line number.
    class InvalidOpeningBalances < StandardError; end

    # Creates an account for each line of the balances file. It stops at the
    # first bad line, because the transfers should not be run against
    # starting balances that cannot be trusted.
    class LoadAccounts
      def initialize(accounts:)
        @accounts = accounts
      end

      def call(opening_balances)
        opening_balances.each { |row| add(row) }
      end

      private

      # A domain error only says what is wrong. Re-raising it with the line
      # number in front tells the reader where in the file to look.
      def add(row)
        @accounts.add(build_account(row))
      rescue Domain::Error => e
        raise InvalidOpeningBalances, "line #{row.line}: #{e.message}"
      end

      def build_account(row)
        Domain::Account.new(
          number: Domain::AccountNumber.new(value: row.number),
          balance: Domain::Money.parse(row.balance)
        )
      end
    end
  end
end
