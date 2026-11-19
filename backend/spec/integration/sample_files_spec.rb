# frozen_string_literal: true

# End-to-end check of the original challenge. The two sample files in
# spec/fixtures go through every layer: CSV reading, loading the accounts
# and processing the transfers.
RSpec.describe 'Processing the sample files' do
  let(:accounts) { Bank::Infrastructure::InMemoryAccountRepository.new }

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

  def balance_of(number)
    accounts.find(Bank::Domain::AccountNumber.new(value: number)).balance.to_s
  end

  def total_of_all_balances
    accounts.all.map(&:balance).sum(Bank::Domain::Money.zero).to_s
  end

  {
    '1111234522226789' => '4820.50',
    '1111234522221234' => '9974.40',
    '2222123433331212' => '1550.00',
    '1212343433335665' => '1725.60',
    '3212343433335755' => '48679.50'
  }.each do |number, balance|
    it "leaves account #{number} with #{balance}" do
      process_transfers

      expect(balance_of(number)).to eq(balance)
    end
  end

  it 'completes all four transfers' do
    expect(process_transfers.map(&:completed?)).to eq([true, true, true, true])
  end

  it 'starts with 66750.00 across all accounts' do
    expect(total_of_all_balances).to eq('66750.00')
  end

  it 'neither creates nor loses money' do
    process_transfers

    expect(total_of_all_balances).to eq('66750.00')
  end
end
