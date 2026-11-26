# frozen_string_literal: true

# The `rackup` command reads this file to start the server:
#
#   bundle exec rackup
#
# The server creates its tables if they are missing, but it does not load
# any balances when it starts. Those are put in the database by seeding it.
#
# The balances file is only read when a reset is asked for. With nothing
# else given it is the sample balances. To use a different file, name it in
# BALANCES_FILE.

# Reads DATABASE_URL and any other settings from the `.env` file in this
# folder. It has to come first, because the lines below use those settings.
require 'dotenv/load'

require_relative 'lib/bank'

sample_balances = File.expand_path('spec/fixtures/account_balances.csv', __dir__)
balances_file = ENV.fetch('BALANCES_FILE', sample_balances)

abort "BALANCES_FILE is #{balances_file}, which is not a file." unless File.file?(balances_file)

# The transfers files the page offers to try: the sample day first, then the
# edge cases in alphabetical order.
sample_files = [File.expand_path('spec/fixtures/transfers.csv', __dir__)] +
               Dir[File.expand_path('spec/fixtures/edge_cases/*.csv', __dir__)]

Bank::Interfaces::Api.start(
  database: Bank::Infrastructure::Database.from_environment,
  balances_file: balances_file,
  sample_files: sample_files
)

run Bank::Interfaces::Api
