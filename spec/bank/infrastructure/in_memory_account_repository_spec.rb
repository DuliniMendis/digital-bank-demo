# frozen_string_literal: true

RSpec.describe Bank::Infrastructure::InMemoryAccountRepository do
  subject(:repository) { described_class.new }

  let(:number) { Bank::Domain::AccountNumber.new(value: '1111234522226789') }
  let(:account) { build_account(number) }

  def build_account(account_number)
    Bank::Domain::Account.new(number: account_number, balance: Bank::Domain::Money.new(cents: 1000))
  end

  it 'rejects a second account with the same number' do
    repository.add(account)

    expect { repository.add(build_account(number)) }
      .to raise_error(Bank::Domain::DuplicateAccount, /1111234522226789 already exists/)
  end

  it 'finds an account by its number' do
    repository.add(account)

    expect(repository.find(number)).to be(account)
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
end
