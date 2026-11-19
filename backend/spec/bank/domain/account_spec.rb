# frozen_string_literal: true

RSpec.describe Bank::Domain::Account do
  subject(:account) { described_class.new(number: number, balance: money(1000)) }

  let(:number) { Bank::Domain::AccountNumber.new(value: '1111234522226789') }

  def money(cents)
    Bank::Domain::Money.new(cents: cents)
  end

  describe '.new' do
    it 'rejects a number that is not an AccountNumber' do
      expect { described_class.new(number: '1111234522226789', balance: money(1000)) }
        .to raise_error(Bank::Domain::InvalidAccount, /number must be an account number/)
    end

    it 'rejects a balance that is not Money' do
      expect { described_class.new(number: number, balance: 1000) }
        .to raise_error(Bank::Domain::InvalidAccount, /balance must be money/)
    end
  end

  describe '#deposit' do
    it 'increases the balance' do
      account.deposit(money(250))

      expect(account.balance).to eq(money(1250))
    end
  end

  describe '#withdraw' do
    it 'decreases the balance' do
      account.withdraw(money(400))

      expect(account.balance).to eq(money(600))
    end

    it 'allows the balance to reach exactly zero' do
      account.withdraw(money(1000))

      expect(account.balance).to eq(money(0))
    end

    context 'when the amount is more than the balance' do
      # Lets a spec look at the balance after the withdrawal was refused.
      def withdraw_too_much
        account.withdraw(money(1001))
      rescue Bank::Domain::InsufficientFunds
        nil
      end

      it 'raises InsufficientFunds, naming the account and the amount' do
        expect { account.withdraw(money(1001)) }.to raise_error(
          Bank::Domain::InsufficientFunds,
          'account 1111234522226789 does not have sufficient funds to withdraw $10.01'
        )
      end

      it 'leaves the balance unchanged' do
        expect { withdraw_too_much }.not_to change(account, :balance)
      end
    end
  end
end
