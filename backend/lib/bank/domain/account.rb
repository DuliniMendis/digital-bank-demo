# frozen_string_literal: true

module Bank
  module Domain
    # An account number and its balance. The no-overdraft rule lives here.
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
    end
  end
end
