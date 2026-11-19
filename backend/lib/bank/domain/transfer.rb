# frozen_string_literal: true

module Bank
  module Domain
    # Transfer is one request to move money: which account it comes from,
    # which account it goes to, and how much.
    #
    # It is a value object. `from` and `to` are AccountNumbers and `amount`
    # is Money.
    Transfer = Data.define(:from, :to, :amount) do
      def initialize(from:, to:, amount:)
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
