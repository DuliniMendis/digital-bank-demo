# frozen_string_literal: true

# How a single transfer is applied is covered by the ProcessTransfers specs.
# These examples cover what ApplyTransfersFile adds: the history, and
# refusing a file it has seen before.
RSpec.describe Bank::UseCases::ApplyTransfersFile, :database do
  subject(:apply_file) { described_class.new(accounts: accounts, history: history) }

  let(:accounts) { Bank::Infrastructure::PostgresAccountRepository.new(database) }
  let(:history) { Bank::Infrastructure::PostgresTransferHistory.new(database) }
  let(:alice) { Bank::Domain::AccountNumber.new(value: '1111234522226789') }
  let(:bob) { Bank::Domain::AccountNumber.new(value: '1212343433335665') }
  let(:requests) do
    [Bank::UseCases::TransferRequest.new(line: 1, from: alice.to_s, to: bob.to_s, amount: '3.00')]
  end

  before do
    [alice, bob].each do |number|
      accounts.add(Bank::Domain::Account.new(number: number, balance: Bank::Domain::Money.new(cents: 1000)))
    end
  end

  def balance_of(number)
    accounts.find(number).balance.to_s
  end

  it 'returns the result of each transfer' do
    results = apply_file.call(fingerprint: 'a' * 64, requests: requests)

    expect(results.map(&:completed?)).to eq([true])
  end

  it 'records each result in the history' do
    results = apply_file.call(fingerprint: 'a' * 64, requests: requests)

    expect(history.all.map(&:result)).to eq(results)
  end

  context 'when a file with the same fingerprint was applied before' do
    before { apply_file.call(fingerprint: 'a' * 64, requests: requests) }

    it 'refuses it and moves no money' do
      expect { apply_file.call(fingerprint: 'a' * 64, requests: requests) }
        .to raise_error(Bank::UseCases::TransfersAlreadyApplied).and(not_change { balance_of(alice) })
    end

    it 'applies it when apply_again is true' do
      apply_file.call(fingerprint: 'a' * 64, requests: requests, apply_again: true)

      expect(balance_of(alice)).to eq('4.00')
    end
  end

  context 'when recording the history fails' do
    before { allow(history).to receive(:record).and_raise('the database went away') }

    it 'undoes the transfers, so the file can be sent again' do
      expect { apply_file.call(fingerprint: 'a' * 64, requests: requests) }
        .to raise_error('the database went away').and(not_change { balance_of(alice) })
    end
  end
end
