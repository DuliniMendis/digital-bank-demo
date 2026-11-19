# frozen_string_literal: true

# Loads the opening balances into the database and empties the transfer
# history. Run it once before the server is first started, and again
# whenever the accounts should go back to their opening balances:
#
#   DATABASE_URL=postgres://localhost/bank_development bundle exec ruby db/seed.rb
#
# With nothing else given it loads the sample balances. To load a different
# file, name it in BALANCES_FILE.

require_relative '../lib/bank'

sample_balances = File.expand_path('../spec/fixtures/account_balances.csv', __dir__)
balances_file = ENV.fetch('BALANCES_FILE', sample_balances)

database = Bank::Infrastructure::Database.from_environment
accounts = Bank::Infrastructure::PostgresAccountRepository.new(database)
history = Bank::Infrastructure::PostgresTransferHistory.new(database)
opening_balances = Bank::Infrastructure::CsvFiles.opening_balances(File.read(balances_file))

# A bad line in the file stops the seeding, and whatever the database held
# before is left untouched.
begin
  Bank::UseCases::SeedAccounts.new(accounts: accounts, history: history).call(opening_balances)
rescue Bank::UseCases::InvalidOpeningBalances => e
  abort "Nothing was changed. #{balances_file}, #{e.message}"
end

puts "Seeded #{accounts.all.size} accounts from #{balances_file}"
