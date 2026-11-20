# frozen_string_literal: true

# The `rackup` command reads this file to start the server:
#
#   DATABASE_URL=postgres://localhost/bank_development bundle exec rackup
#
# The server creates its tables if they are missing, but it does not load
# any balances when it starts. Those are put in the database by seeding it.
#
# The balances file is only read when a reset is asked for. With nothing
# else given it is the sample balances. To use a different file, name it in
# BALANCES_FILE.

require_relative 'lib/bank'

sample_balances = File.expand_path('spec/fixtures/account_balances.csv', __dir__)
balances_file = ENV.fetch('BALANCES_FILE', sample_balances)

abort "BALANCES_FILE is #{balances_file}, which is not a file." unless File.file?(balances_file)

Bank::Interfaces::Api.start(
  database: Bank::Infrastructure::Database.from_environment,
  balances_file: balances_file,
  sample_transfers_file: File.expand_path('spec/fixtures/transfers.csv', __dir__)
)

run Bank::Interfaces::Api
