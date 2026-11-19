# frozen_string_literal: true

# Run Sinatra in test mode. In its default development mode it only accepts
# requests addressed to this machine, which would turn away the requests
# made by the specs.
ENV['APP_ENV'] = 'test'

require 'bank'
require_relative 'support/database'

# Lets a spec say "and this did not change" after another expectation.
RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
