# frozen_string_literal: true

module Bank
  module UseCases
    # Fills the database with the opening balances. Any accounts already
    # stored are removed first, so seeding an empty database and seeding one
    # again later (reseeding) are the same operation.
    #
    # It runs in one transaction. If the opening balances are rejected, the
    # error is raised and the accounts already stored are left as they were.
    class SeedAccounts
      def initialize(accounts:)
        @accounts = accounts
      end

      def call(opening_balances)
        @accounts.transaction do
          @accounts.clear
          LoadAccounts.new(accounts: @accounts).call(opening_balances)
        end
      end
    end
  end
end
