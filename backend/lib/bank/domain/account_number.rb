# frozen_string_literal: true

module Bank
  module Domain
    # AccountNumber identifies an account. It is always exactly 16 digits.
    #
    # It is a value object, so an AccountNumber that exists is always valid.
    # The rest of the code never has to re-check the format.
    AccountNumber = Data.define(:value) do
      def initialize(value:)
        digits = value.to_s.strip
        valid = digits.match?(/\A\d{16}\z/)
        raise InvalidAccountNumber, "#{value.inspect} is not a 16 digit account number" unless valid

        super(value: digits)
      end

      def to_s
        value
      end
    end
  end
end
