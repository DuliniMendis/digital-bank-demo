# frozen_string_literal: true

module Bank
  module Domain
    # Transfer is one request to move money: which account it comes from,
    # which account it goes to, and how much.
    #
    # It is a value object. `from` and `to` are AccountNumbers and `amount`
    # is Money. The constructor checks all of this, so a Transfer that
    # exists is always complete and valid.
    Transfer = Data.define(:from, :to, :amount) do
      def initialize(from:, to:, amount:)
        raise InvalidTransfer, 'from must be an account number' unless from.is_a?(AccountNumber)
        raise InvalidTransfer, 'to must be an account number' unless to.is_a?(AccountNumber)
        raise InvalidTransfer, 'amount must be money' unless amount.is_a?(Money)
        raise InvalidTransfer, 'amount must be greater than zero' if amount.zero?
        raise InvalidTransfer, 'from and to accounts must be different' if from == to

        super
      end

      # Moves the money between the two Account objects.
      #
      # The withdrawal happens first. If it is refused, an error is raised
      # before the deposit, so neither balance changes.
      def apply(source:, destination:)
        source.withdraw(amount)
        destination.deposit(amount)
      end
    end
  end
end
