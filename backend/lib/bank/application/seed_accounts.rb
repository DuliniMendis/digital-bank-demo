# frozen_string_literal: true

module Bank
  module Application
    # One line of the balances file: its line number and the two fields as
    # plain text. Nothing has been validated at this point.
    OpeningBalance = Data.define(:line, :number, :balance)

    # Raised when a line of the balances file is rejected. The message starts
    # with the line number.
    class InvalidOpeningBalances < StandardError; end

    # Fills the database with the opening balances: one account for each line
    # of the balances file. Any accounts already stored are removed first, and
    # so is the transfer history, so seeding an empty database and seeding
    # one again later (reseeding) are the same operation.
    #
    # It stops at the first bad line, because the transfers should not be run
    # against starting balances that cannot be trusted. Everything happens in
    # one transaction, so a bad line leaves the accounts and history already
    # stored as they were.
    class SeedAccounts
      def initialize(accounts:, history:)
        @accounts = accounts
        @history = history
      end

      def call(opening_balances)
        @accounts.transaction do
          @history.clear
          @accounts.clear
          opening_balances.each { |row| add(row) }
        end
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
