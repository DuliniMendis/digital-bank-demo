# frozen_string_literal: true

# The `rackup` command reads this file to start the server:
#
#   DATABASE_URL=postgres://localhost/bank_development \
#   BALANCES_FILE=path/to/balances.csv bundle exec rackup
#
# The tables are created and the balances are in place before the server
# accepts its first request.

require_relative 'lib/bank'

database_url = ENV.fetch('DATABASE_URL') do
  abort 'Set DATABASE_URL to the address of the Postgres database.'
end

balances_file = ENV.fetch('BALANCES_FILE') do
  abort 'Set BALANCES_FILE to the path of the account balances CSV file.'
end

database = Bank::Infrastructure::Database.connect(database_url)
Bank::Infrastructure::Database.migrate(database)
Bank::Web::Api.start(database: database, balances_file: balances_file)

run Bank::Web::Api
