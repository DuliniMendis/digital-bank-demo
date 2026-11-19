# frozen_string_literal: true

module Bank
  module Domain
    # An amount of money, held as whole cents. Floats can't represent every
    # cent exactly (0.1 + 0.2 != 0.3); integers can. Never negative.
    Money = Data.define(:cents) do
      # Parses "25.60", "500" or "5.2" (read as $5.20). More than two decimal
      # places is rejected instead of rounded, because rounding would quietly
      # change the amount.
      def self.parse(text)
        cleaned = text.to_s.strip
        raise InvalidMoney, 'amount is missing' if cleaned.empty?

        match = /\A(\d+)(?:\.(\d{1,2}))?\z/.match(cleaned)
        raise InvalidMoney, "#{text.inspect} is not a valid amount" unless match

        new(cents: to_cents(dollars: match[1], decimals: match[2]))
      end

      # decimals is "6" for 60 cents, "60" for the same, or nil for none.
      def self.to_cents(dollars:, decimals:)
        (dollars.to_i * 100) + decimals.to_s.ljust(2, '0').to_i
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

      # "1234.50"
      def to_s
        format('%<dollars>d.%<cents>02d', dollars: cents / 100, cents: cents % 100)
      end
    end
  end
end
