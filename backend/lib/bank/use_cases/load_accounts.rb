# frozen_string_literal: true

module Bank
  module UseCases
    # One line of the balances file, exactly as it was read: the line number
    # and the two pieces of text. Nothing has been checked yet.
    OpeningBalance = Data.define(:line, :number, :balance)

    # The balances file could not be loaded. The message says which line.
    class InvalidOpeningBalances < StandardError; end

    # LoadAccounts sets up the starting state: it turns each line of the
    # balances file into an Account and adds it to the repository.
    #
    # The starting balances must be trustworthy, so one bad line stops the
    # whole load. The error names the line and the reason. The load runs in
    # one transaction, so with a database either every account is stored or
    # none is.
    class LoadAccounts
      def initialize(accounts:)
        @accounts = accounts
      end

      def call(opening_balances)
        @accounts.transaction do
          opening_balances.each { |row| add(row) }
        end
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
