# frozen_string_literal: true

RSpec.describe Bank::UseCases::Reset, :database do
  subject(:reset) { described_class.new(accounts: accounts, history: history) }

  let(:accounts) { Bank::Infrastructure::PostgresAccountRepository.new(database) }
  let(:history) { Bank::Infrastructure::PostgresTransferHistory.new(database) }
  let(:opening_balances) { [row(1, '1111234522226789', '5000.00')] }

  def row(line, number, balance)
    Bank::UseCases::OpeningBalance.new(line: line, number: number, balance: balance)
  end

  def loaded
    accounts.all.map { |account| [account.number.to_s, account.balance.to_s] }
  end

  # An account and a history entry that are not in the opening balances.
  before do
    Bank::UseCases::LoadAccounts.new(accounts: accounts).call([row(1, '1212343433335665', '7.00')])
    request = Bank::UseCases::TransferRequest.new(line: 1, from: 'a', to: 'b', amount: '1')
    history.record('a' * 64, [Bank::UseCases::TransferResult.new(request: request, rejection_reason: 'bad')])
  end

  it 'replaces the accounts with the opening balances' do
    reset.call(opening_balances)

    expect(loaded).to eq([%w[1111234522226789 5000.00]])
  end

  it 'empties the history' do
    reset.call(opening_balances)

    expect(history.all).to be_empty
  end

  it 'changes nothing when the opening balances are rejected' do
    expect { reset.call([row(1, '12345', '1')]) }
      .to raise_error(Bank::UseCases::InvalidOpeningBalances)
      .and(not_change { [loaded, history.all.size] })
  end
end
