# frozen_string_literal: true

RSpec.describe Bank::UseCases::LoadAccounts do
  subject(:load_accounts) { described_class.new(accounts: accounts) }

  let(:accounts) { Bank::Infrastructure::InMemoryAccountRepository.new }

  def row(line, number, balance)
    Bank::UseCases::OpeningBalance.new(line: line, number: number, balance: balance)
  end

  it 'adds an account for each line' do
    load_accounts.call([row(1, '1111234522226789', '5000.00'), row(2, '1111234522221234', '10')])

    expect(accounts.all.map { |account| account.number.to_s })
      .to eq(%w[1111234522226789 1111234522221234])
  end

  it 'sets each balance from the file' do
    load_accounts.call([row(1, '1111234522226789', '5000.00')])

    expect(accounts.all.first.balance).to eq(Bank::Domain::Money.new(cents: 500_000))
  end

  it 'accepts an opening balance of zero' do
    load_accounts.call([row(1, '1111234522226789', '0.00')])

    expect(accounts.all.first.balance).to eq(Bank::Domain::Money.zero)
  end

  context 'when a line is not valid' do
    it 'names the line with a bad account number' do
      expect { load_accounts.call([row(1, '1111234522226789', '1'), row(2, '12345', '1')]) }
        .to raise_error(Bank::UseCases::InvalidOpeningBalances, /\Aline 2: .*16 digit/)
    end

    it 'names the line with a bad balance' do
      expect { load_accounts.call([row(3, '1111234522226789', '-50.00')]) }
        .to raise_error(Bank::UseCases::InvalidOpeningBalances, /\Aline 3: .*not a valid amount/)
    end

    it 'names the line with a missing balance' do
      expect { load_accounts.call([row(4, '1111234522226789', nil)]) }
        .to raise_error(Bank::UseCases::InvalidOpeningBalances, 'line 4: amount is missing')
    end

    it 'names the line that repeats an account number' do
      rows = [row(1, '1111234522226789', '1'), row(2, '1111234522226789', '2')]

      expect { load_accounts.call(rows) }
        .to raise_error(Bank::UseCases::InvalidOpeningBalances, /\Aline 2: .*already exists/)
    end
  end
end
