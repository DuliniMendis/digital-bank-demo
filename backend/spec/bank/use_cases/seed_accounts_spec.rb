# frozen_string_literal: true

RSpec.describe Bank::UseCases::SeedAccounts, :database do
  subject(:seed_accounts) { described_class.new(accounts: accounts) }

  let(:accounts) { Bank::Infrastructure::PostgresAccountRepository.new(database) }

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

  context 'when the database was seeded before' do
    before { seed_accounts.call([row(1, '1212343433335665', '7.00')]) }

    it 'replaces the accounts already stored' do
      seed_accounts.call([row(1, '1111234522226789', '5000.00')])

      expect(stored).to eq([%w[1111234522226789 5000.00]])
    end

    it 'leaves them as they were when the opening balances are rejected' do
      expect { seed_accounts.call([row(1, '12345', '1')]) }
        .to raise_error(Bank::UseCases::InvalidOpeningBalances).and(not_change { stored })
    end
  end
end
