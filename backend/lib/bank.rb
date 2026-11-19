# frozen_string_literal: true

# Four layers. Each one only depends on the ones listed above it.
#
#   domain          business rules
#   use_cases       what the app does with them
#   infrastructure  CSV parsing and in-memory storage
#   web             HTTP API
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
require_relative 'bank/infrastructure/csv_files'

require_relative 'bank/web/api'
