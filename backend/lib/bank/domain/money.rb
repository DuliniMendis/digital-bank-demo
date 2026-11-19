# frozen_string_literal: true

module Bank
  module Domain
    # Money is an amount of dollars and cents, for example a balance or the
    # amount of a transfer.
    #
    # It is a value object: it has no identity, two Money objects with the
    # same amount are equal, and it can never be changed after it is created.
    # Adding or subtracting returns a new Money.
    #
    # The amount is stored as a whole number of cents. Decimal numbers
    # (floats) cannot represent every cent exactly, so 0.1 + 0.2 would not
    # equal 0.3. Whole numbers do not have that problem.
    #
    # Money is never negative in this system.
    Money = Data.define(:cents) do
      # Builds Money from text such as "25.60", "500" or "0.5".
      #
      # One decimal digit is accepted: "5.2" means $5.20. It can only mean
      # one thing, and spreadsheets often drop the trailing zero when they
      # export a CSV file.
      #
      # Three or more decimal digits are rejected: "5.100" raises
      # InvalidMoney. Dropping or rounding the extra digits would silently
      # change the amount, so it is safer to refuse.
      def self.parse(text)
        cleaned = text.to_s.strip
        raise InvalidMoney, 'amount is missing' if cleaned.empty?

        match = /\A(\d+)(?:\.(\d{1,2}))?\z/.match(cleaned)
        raise InvalidMoney, "#{text.inspect} is not a valid amount" unless match

        new(cents: to_cents(dollars: match[1], decimals: match[2]))
      end

      # Turns the two halves of "25.6" into 2560 cents. The decimals may be
      # missing ("25") and are padded on the right, so "6" means 60 cents.
      def self.to_cents(dollars:, decimals:)
        (dollars.to_i * 100) + decimals.to_s.ljust(2, '0').to_i
      end

      def self.zero
        new(cents: 0)
      end

      def initialize(cents:)
        valid = cents.is_a?(Integer) && !cents.negative?
        raise InvalidMoney, "#{cents.inspect} is not a valid number of cents" unless valid

        super
      end

      def +(other)
        with(cents: cents + other.cents)
      end

      def -(other)
        with(cents: cents - other.cents)
      end

      def >(other)
        cents > other.cents
      end

      def zero?
        cents.zero?
      end

      # Formats as dollars and two-digit cents, for example "1234.50".
      def to_s
        format('%<dollars>d.%<cents>02d', dollars: cents / 100, cents: cents % 100)
      end
    end
  end
end
