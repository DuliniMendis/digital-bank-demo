# frozen_string_literal: true

module Bank
  module Domain
    # An account, identified by its number, with a balance that changes as
    # money moves in and out. It enforces the rule that a balance cannot go
    # below zero.
    class Account
      attr_reader :number, :balance

      def initialize(number:, balance:)
        raise InvalidAccount, 'number must be an account number' unless number.is_a?(AccountNumber)
        raise InvalidAccount, 'balance must be money' unless balance.is_a?(Money)

        @number = number
        @balance = balance
      end

      def deposit(amount)
        @balance += amount
      end

      def withdraw(amount)
        if amount > balance
          raise InsufficientFunds,
                "account #{number} does not have sufficient funds to withdraw $#{amount}"
        end

        @balance -= amount
      end

      # True when the account could not pay `outgoing` even after `incoming`
      # has arrived. It is the rule from `withdraw`, asked about a whole
      # file at once: only the balance at the end has to stay at or above
      # zero.
      def overdrawn_after?(incoming:, outgoing:)
        outgoing > balance + incoming
      end

      # Two accounts are the same account if their numbers match, whatever
      # their balances.
      def ==(other)
        other.is_a?(Account) && number == other.number
      end

      # Ruby does not use `==` when it compares Hash keys or removes
      # duplicates with `uniq`. It uses `eql?` and `hash`, so they are
      # defined from the number as well and all three agree.
      alias eql? ==

      def hash
        number.hash
      end
    end
  end
end
