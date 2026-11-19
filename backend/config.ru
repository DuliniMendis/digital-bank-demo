# frozen_string_literal: true

# The `rackup` command reads this file to start the server:
#
#   bundle exec rackup
#
# With nothing else given it loads the sample balances. To load a different
# file, name it in BALANCES_FILE:
#
#   BALANCES_FILE=path/to/balances.csv bundle exec rackup
#
# The balances file is loaded first, so the server never accepts a request
# without its accounts in place.

require_relative 'lib/bank'

sample_balances = File.expand_path('spec/fixtures/account_balances.csv', __dir__)
balances_file = ENV.fetch('BALANCES_FILE', sample_balances)

Bank::Web::Api.load_balances(balances_file)
puts "Loaded account balances from #{balances_file}"

run Bank::Web::Api
