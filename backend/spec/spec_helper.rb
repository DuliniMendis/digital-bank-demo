# frozen_string_literal: true

# Sinatra's development mode only answers requests addressed to localhost,
# which the test client's are not.
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
