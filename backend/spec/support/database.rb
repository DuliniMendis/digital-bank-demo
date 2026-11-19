# frozen_string_literal: true

# Specs tagged with :database talk to a real Postgres database. Its address
# comes from the DATABASE_URL environment variable, or defaults to a local
# database called bank_test.
#
# Specs without the tag never connect, so they run without Postgres.
module DatabaseHelper
  URL = ENV.fetch('DATABASE_URL', 'postgres://localhost/bank_test')

  # Connects the first time it is needed, and creates the tables.
  def self.database
    @database ||= Bank::Infrastructure::Database.connect(URL).tap do |database|
      Bank::Infrastructure::Database.migrate(database)
    end
  end

  def database
    DatabaseHelper.database
  end
end

RSpec.configure do |config|
  config.include DatabaseHelper, :database

  # Each :database example runs inside a transaction that is always undone
  # at the end, so no example sees rows left behind by another.
  config.around(:each, :database) do |example|
    DatabaseHelper.database.transaction(rollback: :always, auto_savepoint: true) do
      example.run
    end
  end
end
