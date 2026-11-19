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

      # Two accounts are the same account if their numbers match, whatever
      # their balances.
      def ==(other)
        other.is_a?(Account) && number == other.number
      end
    end
  end
end
