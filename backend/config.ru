# frozen_string_literal: true

# BALANCES_FILE=spec/fixtures/account_balances.csv bundle exec rackup

require_relative 'lib/bank'

balances_file = ENV.fetch('BALANCES_FILE') do
  abort 'Set BALANCES_FILE to the path of the account balances CSV file.'
end

Bank::Web::Api.load_balances(balances_file)

run Bank::Web::Api
