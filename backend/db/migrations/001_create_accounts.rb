# frozen_string_literal: true

# A migration is one step in building the database. Sequel runs the files
# in this folder in number order and remembers which ones it has run.
Sequel.migration do
  change do
    create_table(:accounts) do
      # `id` only records the order the accounts were added in.
      primary_key :id

      # Sixteen digits, and the same number can never be stored twice.
      String :number, size: 16, null: false, unique: true

      # Whole cents, to match Money. The database refuses a negative
      # balance as a last line of defence behind Account#withdraw.
      Bignum :balance_cents, null: false
      constraint(:balance_is_not_negative) { balance_cents >= 0 }
    end
  end
end
