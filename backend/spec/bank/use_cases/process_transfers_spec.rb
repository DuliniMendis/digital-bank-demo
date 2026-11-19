# frozen_string_literal: true

# The money rules themselves are covered by the domain specs. These examples
# cover what ProcessTransfers adds on top: finding the accounts, turning a
# refusal into a rejection, and working through the list in order.
RSpec.describe Bank::UseCases::ProcessTransfers do
  subject(:process_transfers) { described_class.new(accounts: accounts) }

  let(:accounts) { Bank::Infrastructure::InMemoryAccountRepository.new }
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
    Bank::UseCases::TransferRequest.new(line: line, from: from, to: to, amount: amount)
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
end
