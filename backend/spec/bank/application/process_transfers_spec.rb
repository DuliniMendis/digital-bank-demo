# frozen_string_literal: true

# The money rules themselves are covered by the domain specs. These examples
# cover what ProcessTransfers adds on top: finding the accounts, turning a
# refusal into a rejection, working through the list in order, recording the
# history, and refusing a file it has seen before.
RSpec.describe Bank::Application::ProcessTransfers, :database do
  subject(:process_transfers) { described_class.new(accounts: accounts, history: history) }

  let(:accounts) { Bank::Infrastructure::AccountRepository.new(database) }
  let(:history) { Bank::Infrastructure::TransferHistory.new(database) }
  let(:alice) { '1111234522226789' }
  let(:bob) { '1212343433335665' }
  let(:stranger) { '9999999999999999' }

  before do
    add_account(alice, 1000)
    add_account(bob, 50)
  end

  def add_account(number, cents)
    accounts.add(
      Bank::Domain::Account.new(
        number: Bank::Domain::AccountNumber.new(value: number),
        balance: Bank::Domain::Money.new(cents: cents)
      )
    )
  end

  def request(from, to, amount, line: 1)
    Bank::Application::TransferRequest.new(line: line, from: from, to: to, amount: amount)
  end

  def balance_of(number)
    accounts.find(Bank::Domain::AccountNumber.new(value: number)).balance.to_s
  end

  # Applies the requests as one file. Every file in these examples is given
  # the same fingerprint unless the example says otherwise.
  def process(requests, fingerprint: 'a' * 64, apply_again: false)
    process_transfers.call(requests, fingerprint: fingerprint, apply_again: apply_again)
  end

  context 'when the transfer is valid' do
    it 'reports it as completed' do
      results = process([request(alice, bob, '3.00')])

      expect(results.first).to be_completed
    end

    it 'moves the money between the stored accounts' do
      process([request(alice, bob, '3.00')])

      expect([balance_of(alice), balance_of(bob)]).to eq(['7.00', '3.50'])
    end
  end

  context 'when the domain refuses the transfer' do
    it 'rejects a transfer the sender cannot afford, with the reason' do
      results = process([request(alice, bob, '10.01')])

      expect(results.first.rejection_reason).to include('does not have sufficient funds')
    end

    it 'rejects a line that cannot be read, with the reason' do
      results = process([request(alice, bob, 'abc')])

      expect(results.first.rejection_reason).to eq('"abc" is not a valid amount')
    end
  end

  context 'when the receiving account does not exist' do
    it 'rejects the transfer' do
      results = process([request(alice, stranger, '1.00')])

      expect(results.first.rejection_reason).to eq('account 9999999999999999 does not exist')
    end

    it 'takes nothing from the sender' do
      process([request(alice, stranger, '1.00')])

      expect(balance_of(alice)).to eq('10.00')
    end
  end

  # This is why the money is moved inside a transaction.
  context 'when saving fails halfway through a transfer' do
    before do
      receiver = having_attributes(number: Bank::Domain::AccountNumber.new(value: bob))
      allow(accounts).to receive(:save).and_call_original
      allow(accounts).to receive(:save).with(receiver).and_raise('the database went away')
    end

    it 'undoes the withdrawal that was already saved' do
      expect { process([request(alice, bob, '3.00')]) }
        .to raise_error('the database went away').and(not_change { balance_of(alice) })
    end
  end

  context 'with several transfers' do
    def requests
      [
        request(alice, bob, '99.00', line: 1), # rejected: more than Alice has
        request(alice, bob, '4.00', line: 2),
        request(bob, alice, '4.50', line: 3) # only affordable because line 2 ran first
      ]
    end

    it 'carries on after a rejected transfer' do
      results = process(requests)

      expect(results.map(&:completed?)).to eq([false, true, true])
    end

    it 'applies them in order, so a later transfer can spend earlier income' do
      process(requests)

      expect(balance_of(bob)).to eq('0.00')
    end
  end

  it 'records each result in the history' do
    results = process([request(alice, bob, '3.00'), request(alice, stranger, '1.00', line: 2)])

    expect(history.all.map(&:result)).to eq(results)
  end

  context 'when a file with the same fingerprint was applied before' do
    before { process([request(alice, bob, '3.00')]) }

    it 'refuses it and moves no money' do
      expect { process([request(alice, bob, '3.00')]) }
        .to raise_error(Bank::Application::TransfersAlreadyApplied).and(not_change { balance_of(alice) })
    end

    it 'applies it when apply_again is true' do
      process([request(alice, bob, '3.00')], apply_again: true)

      expect(balance_of(alice)).to eq('4.00')
    end
  end

  context 'when recording the history fails' do
    before { allow(history).to receive(:record).and_raise('the database went away') }

    it 'undoes the transfers, so the file can be sent again' do
      expect { process([request(alice, bob, '3.00')]) }
        .to raise_error('the database went away').and(not_change { balance_of(alice) })
    end
  end
end
