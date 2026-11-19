# frozen_string_literal: true

RSpec.describe Bank::Domain::Transfer do
  subject(:transfer) do
    described_class.new(from: from, to: to, amount: money(300))
  end

  let(:from) { Bank::Domain::AccountNumber.new(value: '1111234522226789') }
  let(:to) { Bank::Domain::AccountNumber.new(value: '1212343433335665') }
  let(:source) { Bank::Domain::Account.new(number: from, balance: money(1000)) }
  let(:destination) { Bank::Domain::Account.new(number: to, balance: money(50)) }

  def money(cents)
    Bank::Domain::Money.new(cents: cents)
  end

  # Runs the transfer and swallows the refusal, so a spec can check what
  # happened to the balances afterwards.
  def apply_ignoring_refusal
    transfer.apply(source: source, destination: destination)
  rescue Bank::Domain::InsufficientFunds
    nil
  end

  describe '.new' do
    it 'rejects a missing from account' do
      expect { described_class.new(from: nil, to: to, amount: money(300)) }
        .to raise_error(Bank::Domain::InvalidTransfer, /from must be an account number/)
    end

    it 'rejects a missing to account' do
      expect { described_class.new(from: from, to: nil, amount: money(300)) }
        .to raise_error(Bank::Domain::InvalidTransfer, /to must be an account number/)
    end

    it 'rejects an account given as plain text' do
      expect { described_class.new(from: '1111234522226789', to: to, amount: money(300)) }
        .to raise_error(Bank::Domain::InvalidTransfer, /from must be an account number/)
    end

    it 'rejects a missing amount' do
      expect { described_class.new(from: from, to: to, amount: nil) }
        .to raise_error(Bank::Domain::InvalidTransfer, /amount must be money/)
    end

    it 'rejects an amount given as a plain number' do
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

      it 'raises InsufficientFunds' do
        expect { transfer.apply(source: source, destination: destination) }
          .to raise_error(Bank::Domain::InsufficientFunds)
      end

      it 'leaves the source balance unchanged' do
        expect { apply_ignoring_refusal }.not_to change(source, :balance)
      end

      it 'leaves the destination balance unchanged' do
        expect { apply_ignoring_refusal }.not_to change(destination, :balance)
      end
    end
  end
end
