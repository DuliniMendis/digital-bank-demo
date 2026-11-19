# frozen_string_literal: true

module Bank
  module Infrastructure
    # A repository is where accounts are kept and looked up. The use cases
    # talk to a repository and do not care how it stores things.
    #
    # This one keeps accounts in memory, in a Hash keyed by account number.
    # It lets the use cases run, and be tested, without a database.
    # PostgresAccountRepository has the same methods and stores accounts
    # for real.
    #
    # The rule "an account number can only exist once" lives here, because
    # it is a rule about the whole collection and not about one account.
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

      # Nothing to do here: `find` hands out the stored object itself, so a
      # change to its balance is already kept.
      def save(_account); end

      def all
        @accounts.values
      end

      # There is no database to undo anything, so this only runs the block.
      def transaction
        yield
      end
    end
  end
end
