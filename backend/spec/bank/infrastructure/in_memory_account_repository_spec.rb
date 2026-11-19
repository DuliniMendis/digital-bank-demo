# frozen_string_literal: true

RSpec.describe Bank::Infrastructure::InMemoryAccountRepository do
  subject(:repository) { described_class.new }

  it_behaves_like 'an account repository'
end
