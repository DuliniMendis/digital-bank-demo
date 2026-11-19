# frozen_string_literal: true

module Bank
  module Infrastructure
    # A repository is where accounts are kept and looked up. The use cases
    # talk to a repository and do not care how it stores things.
    #
    # This one keeps accounts in memory, in a Hash keyed by account number.
    # A day's balances are loaded, the transfers are applied and the result
    # is read back, all without a database. Storing accounts somewhere
    # else would mean writing another class with the same three methods.
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
