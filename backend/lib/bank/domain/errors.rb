# frozen_string_literal: true

module Bank
  module Domain
    # Base class, so callers can rescue any broken business rule in one go.
    class Error < StandardError; end

    class InvalidMoney < Error; end
    class InvalidAccountNumber < Error; end
    class InvalidAccount < Error; end
    class InvalidTransfer < Error; end
    class DuplicateAccount < Error; end
    class UnknownAccount < Error; end
    class InsufficientFunds < Error; end
  end
end
