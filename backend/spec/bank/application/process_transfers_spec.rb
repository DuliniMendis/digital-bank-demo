# frozen_string_literal: true

# The money rules themselves are covered by the domain specs. These examples
# cover what ProcessTransfers adds on top: finding the accounts, turning a
# refusal into a rejection, and working through the list in order.
RSpec.describe Bank::Application::ProcessTransfers, :database do
  subject(:process_transfers) { described_class.new(accounts: accounts) }

  let(:accounts) { Bank::Infrastructure::AccountRepository.new(database) }
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

  context 'when the transfer is valid' do
    it 'reports it as completed' do
      results = process_transfers.call([request(alice, bob, '3.00')])

      expect(results.first).to be_completed
    end

    it 'moves the money between the stored accounts' do
      process_transfers.call([request(alice, bob, '3.00')])

      expect([balance_of(alice), balance_of(bob)]).to eq(['7.00', '3.50'])
    end
  end

  context 'when the domain refuses the transfer' do
    it 'rejects a transfer the sender cannot afford, with the reason' do
      results = process_transfers.call([request(alice, bob, '10.01')])

      expect(results.first.rejection_reason).to include('does not have sufficient funds')
    end

    it 'rejects a line that cannot be read, with the reason' do
      results = process_transfers.call([request(alice, bob, 'abc')])

      expect(results.first.rejection_reason).to eq('"abc" is not a valid amount')
    end
  end

  context 'when the receiving account does not exist' do
    it 'rejects the transfer' do
      results = process_transfers.call([request(alice, stranger, '1.00')])

      expect(results.first.rejection_reason).to eq('account 9999999999999999 does not exist')
    end

    it 'takes nothing from the sender' do
      process_transfers.call([request(alice, stranger, '1.00')])

      expect(balance_of(alice)).to eq('10.00')
    end
  end

  # This is why each transfer runs in a transaction.
  context 'when saving fails halfway through a transfer' do
    before do
      receiver = having_attributes(number: Bank::Domain::AccountNumber.new(value: bob))
      allow(accounts).to receive(:save).and_call_original
      allow(accounts).to receive(:save).with(receiver).and_raise('the database went away')
    end

    it 'undoes the withdrawal that was already saved' do
      expect { process_transfers.call([request(alice, bob, '3.00')]) }
        .to raise_error('the database went away').and(not_change { balance_of(alice) })
    end
  end

  context 'with several transfers' do
    let(:requests) do
      [
        request(alice, bob, '99.00', line: 1), # rejected: more than Alice has
        request(alice, bob, '4.00', line: 2),
        request(bob, alice, '4.50', line: 3) # only affordable because line 2 ran first
      ]
    end

    it 'carries on after a rejected transfer' do
      results = process_transfers.call(requests)

      expect(results.map(&:completed?)).to eq([false, true, true])
    end

    it 'applies them in order, so a later transfer can spend earlier income' do
      process_transfers.call(requests)

      expect(balance_of(bob)).to eq('0.00')
    end
  end

  # Bob starts with $0.50, so line 1 is more than he has until line 2 has
  # paid him.
  context 'when settling at the end' do
    let(:requests) do
      [
        request(bob, alice, '4.00', line: 1),
        request(alice, bob, '5.00', line: 2)
      ]
    end

    it 'completes a transfer that a later line pays for' do
      results = process_transfers.call(requests, settle_at_end: true)

      expect(results.map(&:completed?)).to eq([true, true])
    end

    it 'leaves each account with its balance after the whole file' do
      process_transfers.call(requests, settle_at_end: true)

      expect([balance_of(alice), balance_of(bob)]).to eq(['9.00', '1.50'])
    end

    it 'rejects that transfer when the flag is not given' do
      results = process_transfers.call(requests)

      expect(results.map(&:completed?)).to eq([false, true])
    end
  end

  context 'when settling at the end would leave an account below $0' do
    let(:requests) do
      [
        request(alice, bob, '1.00', line: 1),
        request(bob, alice, '9.00', line: 2)
      ]
    end

    it 'rejects every transfer in the file, naming the account' do
      results = process_transfers.call(requests, settle_at_end: true)

      expect(results.map(&:rejection_reason).uniq)
        .to eq(['nothing in this file was applied, because it would leave 1212343433335665 below $0'])
    end

    it 'changes no balance' do
      process_transfers.call(requests, settle_at_end: true)

      expect([balance_of(alice), balance_of(bob)]).to eq(['10.00', '0.50'])
    end
  end

  context 'when settling at the end with a line that cannot be used' do
    let(:requests) do
      [
        request(alice, stranger, '1.00', line: 1),
        request(alice, bob, '3.00', line: 2)
      ]
    end

    it 'rejects that line by itself and applies the rest' do
      results = process_transfers.call(requests, settle_at_end: true)

      expect(results.map(&:rejection_reason)).to eq(['account 9999999999999999 does not exist', nil])
    end
  end
end
