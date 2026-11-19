# frozen_string_literal: true

module Bank
  module Domain
    # Account is a customer's account: an account number and a balance.
    #
    # It is an entity: it is identified by its number, and its balance changes
    # over time. Two Account objects with the same number are the same account.
    #
    # The rule "a balance can never go below $0" lives here and nowhere else.
    class Account
      attr_reader :number, :balance

      def initialize(number:, balance:)
        @number = number
        @balance = balance
      end

      def deposit(amount)
        @balance += amount
      end

      # Takes money out. Taking the balance to exactly $0 is allowed.
      def withdraw(amount)
        if amount > balance
          raise InsufficientFunds,
                "account #{number} has #{balance} and cannot pay #{amount}"
        end

        @balance -= amount
      end

      def ==(other)
        other.is_a?(Account) && number == other.number
      end
    end
  end
end
