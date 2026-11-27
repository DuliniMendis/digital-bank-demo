# frozen_string_literal: true

RSpec.describe Bank::Domain::Transfer do
  subject(:transfer) { described_class.new(from: from, to: to, amount: money(300)) }

  let(:from) { Bank::Domain::AccountNumber.new(value: '1111234522226789') }
  let(:to) { Bank::Domain::AccountNumber.new(value: '1212343433335665') }
  let(:source) { Bank::Domain::Account.new(number: from, balance: money(1000)) }
  let(:destination) { Bank::Domain::Account.new(number: to, balance: money(50)) }

  def money(cents)
    Bank::Domain::Money.new(cents: cents)
  end

  describe '.new' do
    it 'rejects a from that is not an AccountNumber' do
      expect { described_class.new(from: '1111234522226789', to: to, amount: money(300)) }
        .to raise_error(Bank::Domain::InvalidTransfer, /from must be an account number/)
    end

    it 'rejects a to that is not an AccountNumber' do
      expect { described_class.new(from: from, to: nil, amount: money(300)) }
        .to raise_error(Bank::Domain::InvalidTransfer, /to must be an account number/)
    end

    it 'rejects an amount that is not Money' do
      expect { described_class.new(from: from, to: to, amount: 300) }
        .to raise_error(Bank::Domain::InvalidTransfer, /amount must be money/)
    end

    it 'rejects an amount of zero' do
      expect { described_class.new(from: from, to: to, amount: money(0)) }
        .to raise_error(Bank::Domain::InvalidTransfer, /greater than zero/)
    end

    it 'rejects a transfer from an account to itself' do
      expect { described_class.new(from: from, to: from, amount: money(300)) }
        .to raise_error(Bank::Domain::InvalidTransfer, /must be different/)
    end
  end

  describe '#apply' do
    it 'takes the amount out of the source account' do
      transfer.apply(source: source, destination: destination)

      expect(source.balance).to eq(money(700))
    end

    it 'puts the amount into the destination account' do
      transfer.apply(source: source, destination: destination)

      expect(destination.balance).to eq(money(350))
    end

    context 'when the source account cannot afford it' do
      let(:source) { Bank::Domain::Account.new(number: from, balance: money(299)) }

      # A refused transfer raises an error, which would end the example. This
      # swallows the error so the example can go on to check the destination.
      def apply_refused_transfer
        transfer.apply(source: source, destination: destination)
      rescue Bank::Domain::InsufficientFunds
        nil
      end

      it 'deposits nothing' do
        expect { apply_refused_transfer }.not_to change(destination, :balance)
      end
    end

    context 'when it is handed an account the transfer does not name' do
      let(:other_account) do
        Bank::Domain::Account.new(
          number: Bank::Domain::AccountNumber.new(value: '3212343433335755'),
          balance: money(1000)
        )
      end

      it 'refuses a source that is not the from account' do
        expect { transfer.apply(source: other_account, destination: destination) }
          .to raise_error(ArgumentError, 'source must be account 1111234522226789')
      end

      it 'refuses a destination that is not the to account' do
        expect { transfer.apply(source: source, destination: other_account) }
          .to raise_error(ArgumentError, 'destination must be account 1212343433335665')
      end
    end
  end
end
