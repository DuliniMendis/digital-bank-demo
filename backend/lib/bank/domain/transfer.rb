# frozen_string_literal: true

module Bank
  module Domain
    # A request to move an amount of money from one account to another. A
    # Transfer cannot be created if the request makes no sense, for example
    # a zero amount or the same account on both sides.
    Transfer = Data.define(:from, :to, :amount) do
      def initialize(from:, to:, amount:)
        raise InvalidTransfer, 'from must be an account number' unless from.is_a?(AccountNumber)
        raise InvalidTransfer, 'to must be an account number' unless to.is_a?(AccountNumber)
        raise InvalidTransfer, 'amount must be money' unless amount.is_a?(Money)
        raise InvalidTransfer, 'amount must be greater than zero' if amount.zero?
        raise InvalidTransfer, 'from and to accounts must be different' if from == to

        super
      end

      # Withdraws first. If that is refused, deposit does not go ahead.
      def apply(source:, destination:)
        source.withdraw(amount)
        destination.deposit(amount)
      end
    end
  end
end
