# frozen_string_literal: true

module Bank
  module UseCases
    # Puts the system back to how it was before any transfers file arrived:
    # the history is emptied and the accounts are replaced with the opening
    # balances.
    #
    # It runs in one transaction. If the opening balances are rejected, the
    # error is raised and the existing accounts and history are left as they
    # were.
    class Reset
      def initialize(accounts:, history:)
        @accounts = accounts
        @history = history
      end

      def call(opening_balances)
        @accounts.transaction do
          @history.clear
          @accounts.clear
          LoadAccounts.new(accounts: @accounts).call(opening_balances)
        end
      end
    end
  end
end
