# frozen_string_literal: true

# The code is organised into four layers. A layer may use the layers listed
# above it but never the ones below, so the business rules in `domain` do not
# depend on CSV files, on the database or on HTTP.
#
#   domain          the business rules
#   use_cases       the operations the app performs, built from the domain
#   infrastructure  reading CSV files, and storing the accounts in Postgres
#   web             the HTTP API
module Bank
end

require_relative 'bank/domain/errors'
require_relative 'bank/domain/money'
require_relative 'bank/domain/account_number'
require_relative 'bank/domain/account'
require_relative 'bank/domain/transfer'

require_relative 'bank/use_cases/seed_accounts'
require_relative 'bank/use_cases/process_transfers'

require_relative 'bank/infrastructure/database'
require_relative 'bank/infrastructure/postgres_account_repository'
require_relative 'bank/infrastructure/csv_files'

require_relative 'bank/web/api'
