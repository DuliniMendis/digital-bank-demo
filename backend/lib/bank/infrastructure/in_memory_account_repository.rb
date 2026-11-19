# frozen_string_literal: true

module Bank
  module Infrastructure
    # Keeps the accounts in a Hash, keyed by account number, for as long as
    # the process runs. Nothing is written to disk. It has the same methods as
    # PostgresAccountRepository, so the use cases work with either one.
    #
    # A duplicate account number is caught here, because being unique is a
    # rule about the whole collection of accounts and not about any one of
    # them.
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

      # `find` hands out the stored object itself, so a change to its balance
      # is already kept and there is nothing left to write.
      def save(_account); end

      def all
        @accounts.values
      end

      def clear
        @accounts.clear
      end

      # There is no database to undo anything, so this only runs the block.
      def transaction
        yield
      end
    end
  end
end
