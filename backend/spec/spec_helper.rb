# frozen_string_literal: true

require 'bank'
require_relative 'support/database'
require_relative 'support/account_repository_examples'

# Lets a spec say "and this did not change" after another expectation.
RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
