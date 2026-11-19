# frozen_string_literal: true

# Bank is the top-level namespace for the banking service.
#
# The code is split into four layers, and each layer only depends on the
# layers listed above it:
#
#   domain          business rules, in plain Ruby
#   use_cases       what the application does, using the domain
#   infrastructure  CSV files and storage (in memory or Postgres)
#   web             the HTTP API
module Bank
end

require_relative 'bank/domain/errors'
require_relative 'bank/domain/money'
require_relative 'bank/domain/account_number'
require_relative 'bank/domain/account'
require_relative 'bank/domain/transfer'

require_relative 'bank/use_cases/load_accounts'
require_relative 'bank/use_cases/process_transfers'

require_relative 'bank/infrastructure/in_memory_account_repository'
require_relative 'bank/infrastructure/database'
require_relative 'bank/infrastructure/postgres_account_repository'
require_relative 'bank/infrastructure/csv_files'
