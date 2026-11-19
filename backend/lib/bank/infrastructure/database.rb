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
    end
  end
end
