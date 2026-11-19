# frozen_string_literal: true

module Bank
  module Domain
    # A request to move an amount from one account to another.
    Transfer = Data.define(:from, :to, :amount) do
      def initialize(from:, to:, amount:)
        raise InvalidTransfer, 'from must be an account number' unless from.is_a?(AccountNumber)
        raise InvalidTransfer, 'to must be an account number' unless to.is_a?(AccountNumber)
        raise InvalidTransfer, 'amount must be money' unless amount.is_a?(Money)
        raise InvalidTransfer, 'amount must be greater than zero' if amount.zero?
        raise InvalidTransfer, 'from and to accounts must be different' if from == to

        super
      end

      # Withdraws first. If that is refused, nothing has been deposited yet.
      def apply(source:, destination:)
        source.withdraw(amount)
        destination.deposit(amount)
      end
    end
  end
end
