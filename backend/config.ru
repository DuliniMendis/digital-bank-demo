# frozen_string_literal: true

# The `rackup` command reads this file to start the server:
#
#   BALANCES_FILE=path/to/balances.csv bundle exec rackup
#
# The balances file is loaded first, so the server never accepts a request
# without its accounts in place.

require_relative 'lib/bank'

balances_file = ENV.fetch('BALANCES_FILE') do
  abort 'Set BALANCES_FILE to the path of the account balances CSV file.'
end

Bank::Web::Api.load_balances(balances_file)

run Bank::Web::Api
