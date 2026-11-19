# frozen_string_literal: true

# The `rackup` command reads this file to start the server:
#
#   DATABASE_URL=postgres://localhost/bank_development bundle exec rackup
#
# The server creates its tables if they are missing, but it does not load
# any balances. Those are put in the database by seeding it.

require_relative 'lib/bank'

Bank::Web::Api.start(database: Bank::Infrastructure::Database.from_environment)

run Bank::Web::Api
