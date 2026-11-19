# frozen_string_literal: true

module Bank
  module Domain
    # Sixteen digits. Checked once here, so nothing else has to check it.
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
