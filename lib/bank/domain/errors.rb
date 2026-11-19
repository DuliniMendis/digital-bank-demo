# frozen_string_literal: true

module Bank
  module Domain
    # Every error raised by a business rule inherits from this class, so a
    # caller can catch all of them with a single `rescue Domain::Error`.
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
