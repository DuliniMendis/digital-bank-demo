# frozen_string_literal: true

module Bank
  module Infrastructure
    # Keeps accounts in the `accounts` table of a Postgres database.
    #
    # Each row is turned into an Account on the way out, and an Account is
    # turned back into a row on the way in. Nothing outside this class sees
    # a database row.
    class AccountRepository
      def initialize(database)
        @database = database
        @table = database[:accounts]
      end

      def add(account)
        @table.insert(number: account.number.to_s, balance_cents: account.balance.cents)
      rescue Sequel::UniqueConstraintViolation
        raise Domain::DuplicateAccount, "account #{account.number} already exists"
      end

      # `for_update` locks the row until the surrounding transaction ends,
      # so two transfers cannot both spend the same balance at once.
      def find(number)
        row = @table.where(number: number.to_s).for_update.first
        raise Domain::UnknownAccount, "account #{number} does not exist" unless row

        to_account(row)
      end

      # Writes an account's current balance back to its row.
      def save(account)
        @table.where(number: account.number.to_s).update(balance_cents: account.balance.cents)
      end

      def all
        @table.order(:id).map { |row| to_account(row) }
      end

      def clear
        @table.delete
      end

      # Everything inside the block is saved together. If the block raises
      # an error, the database undoes all of it.
      def transaction(&)
        @database.transaction(&)
      end

      private

      def to_account(row)
        Domain::Account.new(
          number: Domain::AccountNumber.new(value: row[:number]),
          balance: Domain::Money.new(cents: row[:balance_cents])
        )
      end
    end
  end
end
