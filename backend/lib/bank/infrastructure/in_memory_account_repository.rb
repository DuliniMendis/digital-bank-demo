# frozen_string_literal: true

module Bank
  module Infrastructure
    # Keeps the accounts in a Hash, keyed by account number, for as long as
    # the process runs. Nothing is written to disk.
    #
    # A duplicate account number is caught here and not in Account, because
    # being unique is a rule about the whole collection of accounts.
    class InMemoryAccountRepository
      def initialize
        @accounts = {}
      end

      def add(account)
        number = account.number
        raise Domain::DuplicateAccount, "account #{number} already exists" if @accounts.key?(number)

        @accounts[number] = account
      end

      def find(number)
        @accounts.fetch(number) do
          raise Domain::UnknownAccount, "account #{number} does not exist"
        end
      end

      def all
        @accounts.values
      end
    end
  end
end
