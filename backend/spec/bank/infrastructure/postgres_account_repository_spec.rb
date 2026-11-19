# frozen_string_literal: true

RSpec.describe Bank::Infrastructure::PostgresAccountRepository, :database do
  subject(:repository) { described_class.new(database) }

  let(:account) do
    Bank::Domain::Account.new(
      number: Bank::Domain::AccountNumber.new(value: '1111234522226789'),
      balance: Bank::Domain::Money.new(cents: 1000)
    )
  end

  it_behaves_like 'an account repository'

  # The rest is what only a real database gives us.

  it 'keeps accounts for another repository on the same database' do
    repository.add(account)

    expect(described_class.new(database).all).to eq([account])
  end

  it 'undoes everything in a transaction when its block raises' do
    add_then_fail = -> { repository.transaction { repository.add(account) && raise('stop') } }

    expect { add_then_fail.call }.to raise_error('stop')
      .and(not_change { repository.all.size })
  end

  it 'refuses a negative balance in the database itself' do
    expect { database[:accounts].insert(number: '1111234522226789', balance_cents: -1) }
      .to raise_error(Sequel::CheckConstraintViolation)
  end
end
