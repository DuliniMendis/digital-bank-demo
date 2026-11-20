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

abort "BALANCES_FILE is #{balances_file}, which is not a file." unless File.file?(balances_file)

# A balances file that cannot be used stops the server with one line that
# says what is wrong. Without the rescue the same message would be buried in
# a Ruby backtrace.
begin
  Bank::Interfaces::Api.load_balances(balances_file)
rescue Bank::Application::InvalidOpeningBalances, CSV::MalformedCSVError => e
  abort "#{balances_file} could not be loaded. #{e.message}"
end

puts "Loaded account balances from #{balances_file}"

run Bank::Interfaces::Api
