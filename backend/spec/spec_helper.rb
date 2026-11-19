# frozen_string_literal: true

# Run Sinatra in test mode. In its default development mode it rejects any
# request that is not addressed to localhost, and the test client addresses
# its requests to example.org.
ENV['APP_ENV'] = 'test'

require 'bank'

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
