# frozen_string_literal: true

RSpec.describe Bank::UseCases::SeedAccounts, :database do
  subject(:seed_accounts) { described_class.new(accounts: accounts, history: history) }

  let(:accounts) { Bank::Infrastructure::PostgresAccountRepository.new(database) }
  let(:history) { Bank::Infrastructure::PostgresTransferHistory.new(database) }

  def row(line, number, balance)
    Bank::UseCases::OpeningBalance.new(line: line, number: number, balance: balance)
  end

  def stored
    accounts.all.map { |account| [account.number.to_s, account.balance.to_s] }
  end

  it 'stores the opening balances in an empty database' do
    seed_accounts.call([row(1, '1111234522226789', '5000.00')])

    expect(stored).to eq([%w[1111234522226789 5000.00]])
  end

  context 'when the database was seeded and used before' do
    before do
      seed_accounts.call([row(1, '1212343433335665', '7.00')])
      request = Bank::UseCases::TransferRequest.new(line: 1, from: 'a', to: 'b', amount: '1')
      history.record('a' * 64, [Bank::UseCases::TransferResult.new(request: request, rejection_reason: 'bad')])
    end

    it 'replaces the accounts already stored' do
      seed_accounts.call([row(1, '1111234522226789', '5000.00')])

      expect(stored).to eq([%w[1111234522226789 5000.00]])
    end

    it 'empties the history' do
      seed_accounts.call([row(1, '1111234522226789', '5000.00')])

      expect(history.all).to be_empty
    end

    it 'changes nothing when the opening balances are rejected' do
      expect { seed_accounts.call([row(1, '12345', '1')]) }
        .to raise_error(Bank::UseCases::InvalidOpeningBalances)
        .and(not_change { [stored, history.all.size] })
    end
  end
end
