# frozen_string_literal: true

# Bank is the top-level namespace for the banking service.
#
# The code is split into four layers, and each layer only depends on the
# layers listed above it:
#
#   domain          business rules, in plain Ruby
#   use_cases       what the application does, using the domain
#   infrastructure  CSV files and database storage
#   web             the HTTP API
module Bank
end

require_relative 'bank/domain/errors'
require_relative 'bank/domain/money'
require_relative 'bank/domain/account_number'
require_relative 'bank/domain/account'
require_relative 'bank/domain/transfer'
