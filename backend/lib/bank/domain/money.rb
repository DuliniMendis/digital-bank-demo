# frozen_string_literal: true

module Bank
  module Domain
    # An amount of money, held as whole cents.
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

      # Turns the two halves of "25.6" into 2560 cents.
      # A single digit decimal is padded to the right (ex: 25.6 considered as 25.60)
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

      def to_s
        format('%<dollars>d.%<cents>02d', dollars: cents / 100, cents: cents % 100)
      end
    end
  end
end
