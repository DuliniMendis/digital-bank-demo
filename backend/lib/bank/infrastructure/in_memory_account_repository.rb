# frozen_string_literal: true

module Bank
  module Infrastructure
    # A repository is where accounts are kept and looked up. The use cases
    # talk to a repository and do not care how it stores things.
    #
    # This one keeps accounts in memory, in a Hash keyed by account number.
    # It is used by the command-line runner and by the specs. A database
    # version with the same three methods arrives in a later milestone.
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

      def all
        @accounts.values
      end
    end
  end
end
