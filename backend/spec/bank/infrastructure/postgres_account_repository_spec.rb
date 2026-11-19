# frozen_string_literal: true

RSpec.describe Bank::Infrastructure::PostgresAccountRepository, :database do
  subject(:repository) { described_class.new(database) }

  let(:number) { Bank::Domain::AccountNumber.new(value: '1111234522226789') }
  let(:account) { build_account(number) }

  def money(cents)
    Bank::Domain::Money.new(cents: cents)
  end

  def build_account(account_number)
    Bank::Domain::Account.new(number: account_number, balance: money(1000))
  end

  it 'rejects a second account with the same number' do
    repository.add(account)

    expect { repository.add(build_account(number)) }
      .to raise_error(Bank::Domain::DuplicateAccount, /1111234522226789 already exists/)
  end

  it 'finds an account by its number, with its balance' do
    repository.add(account)

    expect(repository.find(number).balance).to eq(money(1000))
  end

  it 'raises UnknownAccount when no account has that number' do
    expect { repository.find(number) }
      .to raise_error(Bank::Domain::UnknownAccount, /1111234522226789 does not exist/)
  end

  it 'returns the accounts in the order they were added' do
    other = build_account(Bank::Domain::AccountNumber.new(value: '1111234522221234'))
    [account, other].each { |each_account| repository.add(each_account) }

    expect(repository.all).to eq([account, other])
  end

  it 'keeps a balance that was changed and then saved' do
    repository.add(account)
    found = repository.find(number)
    found.deposit(money(500))
    repository.save(found)

    expect(repository.find(number).balance).to eq(money(1500))
  end

  it 'forgets every account when cleared' do
    repository.add(account)
    repository.clear

    expect(repository.all).to be_empty
  end

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
