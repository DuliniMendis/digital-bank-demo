# frozen_string_literal: true

# Loads the opening balances into the database. Run it once before the
# server is first started, and again whenever the accounts should go back to
# their opening balances:
#
#   bundle exec ruby db/seed.rb
#
# With nothing else given it loads the sample balances. To load a different
# file, name it in BALANCES_FILE.

# Reads DATABASE_URL and any other settings from the `.env` file in the
# folder the command is run from.
require 'dotenv/load'

require_relative '../lib/bank'

sample_balances = File.expand_path('../spec/fixtures/account_balances.csv', __dir__)
balances_file = ENV.fetch('BALANCES_FILE', sample_balances)

database = Bank::Infrastructure::Database.from_environment
accounts = Bank::Infrastructure::AccountRepository.new(database)
opening_balances = Bank::Infrastructure::CsvFiles.opening_balances(File.read(balances_file))

# A bad line in the file stops the seeding, and whatever the database held
# before is left untouched.
begin
  Bank::Application::SeedAccounts.new(accounts: accounts).call(opening_balances)
rescue Bank::Application::InvalidOpeningBalances => e
  abort "Nothing was changed. #{balances_file}, #{e.message}"
end

puts "Seeded #{accounts.all.size} accounts from #{balances_file}"
