# frozen_string_literal: true

# These examples cover what SeedAccounts itself does. What makes an account
# number or a balance valid is covered by the domain specs.
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

  it 'stores an account with its balance for each line' do
    seed_accounts.call([row(1, '1111234522226789', '5000.00'), row(2, '1111234522221234', '0')])

    expect(stored).to eq([%w[1111234522226789 5000.00], %w[1111234522221234 0.00]])
  end

  it 'names the line that the domain refuses' do
    expect { seed_accounts.call([row(1, '1111234522226789', '1'), row(2, '12345', '1')]) }
      .to raise_error(Bank::UseCases::InvalidOpeningBalances, /\Aline 2: .*16 digit/)
  end

  it 'names the line that repeats an account number' do
    rows = [row(1, '1111234522226789', '1'), row(2, '1111234522226789', '2')]

    expect { seed_accounts.call(rows) }
      .to raise_error(Bank::UseCases::InvalidOpeningBalances, /\Aline 2: .*already exists/)
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

    it 'leaves both as they were when a line is bad' do
      rows = [row(1, '1111234522226789', '1'), row(2, '12345', '1')]

      expect { seed_accounts.call(rows) }
        .to raise_error(Bank::UseCases::InvalidOpeningBalances)
        .and(not_change { [stored, history.all.size] })
    end
  end
end
