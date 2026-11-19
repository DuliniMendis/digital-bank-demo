# frozen_string_literal: true

# These examples cover what LoadAccounts itself does. What makes an account
# number or a balance valid is tested in spec/bank/domain.
RSpec.describe Bank::UseCases::LoadAccounts do
  subject(:load_accounts) { described_class.new(accounts: accounts) }

  let(:accounts) { Bank::Infrastructure::InMemoryAccountRepository.new }

  def row(line, number, balance)
    Bank::UseCases::OpeningBalance.new(line: line, number: number, balance: balance)
  end

  def loaded
    accounts.all.map { |account| [account.number.to_s, account.balance.to_s] }
  end

  it 'adds an account with its balance for each line' do
    load_accounts.call([row(1, '1111234522226789', '5000.00'), row(2, '1111234522221234', '0')])

    expect(loaded).to eq([%w[1111234522226789 5000.00], %w[1111234522221234 0.00]])
  end

  it 'names the line that the domain refuses' do
    expect { load_accounts.call([row(1, '1111234522226789', '1'), row(2, '12345', '1')]) }
      .to raise_error(Bank::UseCases::InvalidOpeningBalances, /\Aline 2: .*16 digit/)
  end

  it 'names the line that repeats an account number' do
    rows = [row(1, '1111234522226789', '1'), row(2, '1111234522226789', '2')]

    expect { load_accounts.call(rows) }
      .to raise_error(Bank::UseCases::InvalidOpeningBalances, /\Aline 2: .*already exists/)
  end

  context 'with accounts kept in Postgres', :database do
    let(:accounts) { Bank::Infrastructure::PostgresAccountRepository.new(database) }

    it 'stores no accounts at all when one line is bad' do
      rows = [row(1, '1111234522226789', '1'), row(2, '12345', '1')]

      expect { load_accounts.call(rows) }
        .to raise_error(Bank::UseCases::InvalidOpeningBalances).and(not_change { loaded })
    end
  end
end
