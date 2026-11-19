# frozen_string_literal: true

module Bank
  module Infrastructure
    # Holds the accounts in a Hash for as long as the process runs. Also the
    # place where a duplicate account number is caught.
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
