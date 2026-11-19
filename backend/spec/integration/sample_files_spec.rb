# frozen_string_literal: true

# End-to-end check of the original challenge. The two sample files in
# spec/fixtures go through every layer: CSV reading, loading the accounts
# and processing the transfers.
#
# The same checks run twice: once with accounts kept in memory, and once
# with accounts kept in Postgres.
RSpec.shared_examples 'the sample files give the expected result' do
  let(:expected_balances) do
    {
      '1111234522226789' => '4820.50',
      '1111234522221234' => '9974.40',
      '2222123433331212' => '1550.00',
      '1212343433335665' => '1725.60',
      '3212343433335755' => '48679.50'
    }
  end

  before do
    rows = Bank::Infrastructure::CsvFiles.opening_balances(fixture('account_balances.csv'))
    Bank::UseCases::LoadAccounts.new(accounts: accounts).call(rows)
  end

  def fixture(name)
    File.read(File.expand_path("../fixtures/#{name}", __dir__))
  end

  def process_transfers
    rows = Bank::Infrastructure::CsvFiles.transfer_requests(fixture('transfers.csv'))
    Bank::UseCases::ProcessTransfers.new(accounts: accounts).call(rows)
  end

  def balances
    accounts.all.to_h { |account| [account.number.to_s, account.balance.to_s] }
  end

  it 'completes all four transfers' do
    expect(process_transfers.map(&:completed?)).to eq([true, true, true, true])
  end

  it 'leaves every account with the expected balance' do
    process_transfers

    expect(balances).to eq(expected_balances)
  end

  it 'neither creates nor loses money' do
    total = -> { accounts.all.map(&:balance).sum(Bank::Domain::Money.zero) }

    expect { process_transfers }.not_to(change { total.call })
  end
end

RSpec.describe 'Processing the sample files' do
  context 'with accounts kept in memory' do
    let(:accounts) { Bank::Infrastructure::InMemoryAccountRepository.new }

    it_behaves_like 'the sample files give the expected result'
  end

  context 'with accounts kept in Postgres', :database do
    let(:accounts) { Bank::Infrastructure::PostgresAccountRepository.new(database) }

    it_behaves_like 'the sample files give the expected result'
  end
end
