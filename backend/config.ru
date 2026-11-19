# frozen_string_literal: true

# This file starts the server. Run it with:
#
#   BALANCES_FILE=spec/fixtures/account_balances.csv bundle exec rackup
#
# It loads the account balances from that file into memory, then serves the
# API on http://localhost:9292.

require_relative 'lib/bank'

balances_file = ENV.fetch('BALANCES_FILE') do
  abort 'Set BALANCES_FILE to the path of the account balances CSV file.'
end

Bank::Web::Api.load_balances(balances_file)

run Bank::Web::Api
