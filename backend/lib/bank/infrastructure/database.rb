# frozen_string_literal: true

require 'sequel'

module Bank
  module Infrastructure
    # Database opens the connection to Postgres and brings its tables up to
    # date.
    module Database
      MIGRATIONS = File.expand_path('../../../db/migrations', __dir__)

      # `url` looks like postgres://user:password@host/database_name.
      def self.connect(url)
        Sequel.connect(url)
      end

      # Runs any migration in db/migrations that has not been run yet.
      def self.migrate(database)
        Sequel.extension :migration
        Sequel::Migrator.run(database, MIGRATIONS)
      end

      # Connects to the database named in the DATABASE_URL environment
      # variable and brings its tables up to date. The server and the seed
      # script both start this way.
      def self.from_environment
        url = ENV.fetch('DATABASE_URL') do
          abort 'Set DATABASE_URL to the address of the Postgres database.'
        end
        connect(url).tap { |database| migrate(database) }
      end
    end
  end
end
