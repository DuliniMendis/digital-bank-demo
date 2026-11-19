# frozen_string_literal: true

module Bank
  module UseCases
    # A line of the balances file, not yet validated.
    OpeningBalance = Data.define(:line, :number, :balance)

    class InvalidOpeningBalances < StandardError; end

    # Creates an account for each line of the balances file. Stops at the
    # first bad line: we should not run on balances we cannot trust.
    class LoadAccounts
      def initialize(accounts:)
        @accounts = accounts
      end

      def call(opening_balances)
        opening_balances.each { |row| add(row) }
      end

      private

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
