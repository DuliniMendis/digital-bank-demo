# frozen_string_literal: true

module Bank
  module Domain
    # Every business-rule failure inherits from Error, so calling code can
    # rescue all of them at once with `rescue Bank::Domain::Error`.
    class Error < StandardError; end

    # The text or number given is not a valid amount of money.
    class InvalidMoney < Error; end

    # The account number is not exactly 16 digits.
    class InvalidAccountNumber < Error; end

    # The account was built without a proper account number or balance.
    class InvalidAccount < Error; end

    # A withdrawal would take the account balance below $0.
    class InsufficientFunds < Error; end

    # The transfer itself makes no sense (zero amount, or same account twice).
    class InvalidTransfer < Error; end
  end
end
