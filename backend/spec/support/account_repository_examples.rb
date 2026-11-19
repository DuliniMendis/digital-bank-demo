# frozen_string_literal: true

# What every account repository must do, however it stores accounts. The
# in-memory and Postgres repository specs both run these, which is what
# proves the use cases can be given either one.
#
# The spec that includes these must define `repository`.
RSpec.shared_examples 'an account repository' do
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

  it 'runs the block given to transaction' do
    expect { |block| repository.transaction(&block) }.to yield_control
  end
end
