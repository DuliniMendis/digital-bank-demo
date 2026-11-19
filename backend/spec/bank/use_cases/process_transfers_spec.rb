# frozen_string_literal: true

RSpec.describe Bank::UseCases::ProcessTransfers do
  subject(:process_transfers) { described_class.new(accounts: accounts) }

  let(:accounts) { Bank::Infrastructure::InMemoryAccountRepository.new }
  let(:alice) { '1111234522226789' }
  let(:bob) { '1212343433335665' }

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

    it 'takes the amount from the sending account' do
      process_transfers.call([request(alice, bob, '3.00')])

      expect(balance_of(alice)).to eq('7.00')
    end

    it 'adds the amount to the receiving account' do
      process_transfers.call([request(alice, bob, '3.00')])

      expect(balance_of(bob)).to eq('3.50')
    end

    it 'allows the sending account to reach exactly zero' do
      process_transfers.call([request(alice, bob, '10.00')])

      expect(balance_of(alice)).to eq('0.00')
    end
  end

  context 'when the sending account cannot afford it' do
    it 'rejects the transfer and says why' do
      results = process_transfers.call([request(alice, bob, '10.01')])

      expect(results.first.rejection_reason).to include('does not have sufficient funds')
    end

    it 'leaves the sending balance unchanged' do
      process_transfers.call([request(alice, bob, '10.01')])

      expect(balance_of(alice)).to eq('10.00')
    end

    it 'leaves the receiving balance unchanged' do
      process_transfers.call([request(alice, bob, '10.01')])

      expect(balance_of(bob)).to eq('0.50')
    end
  end

  context 'when an account does not exist' do
    let(:stranger) { '9999999999999999' }

    it 'rejects an unknown sending account' do
      results = process_transfers.call([request(stranger, bob, '1.00')])

      expect(results.first.rejection_reason).to eq('account 9999999999999999 does not exist')
    end

    it 'rejects an unknown receiving account' do
      results = process_transfers.call([request(alice, stranger, '1.00')])

      expect(results.first.rejection_reason).to eq('account 9999999999999999 does not exist')
    end

    it 'does not take money when the receiving account is unknown' do
      process_transfers.call([request(alice, stranger, '1.00')])

      expect(balance_of(alice)).to eq('10.00')
    end
  end

  context 'when the line itself is not valid' do
    {
      'a badly formed account number' => %w[12345 1212343433335665 1.00],
      'an amount that is not a number' => %w[1111234522226789 1212343433335665 abc],
      'an amount of zero' => %w[1111234522226789 1212343433335665 0.00],
      'a missing amount' => ['1111234522226789', '1212343433335665', nil],
      'the same account on both sides' => %w[1111234522226789 1111234522226789 1.00]
    }.each do |problem, (from, to, amount)|
      it "rejects #{problem}" do
        results = process_transfers.call([request(from, to, amount)])

        expect(results.first).not_to be_completed
      end
    end
  end

  context 'with several transfers' do
    let(:requests) do
      [
        request(alice, bob, '99.00', line: 1), # rejected: more than Alice has
        request(alice, bob, '4.00', line: 2),
        request(bob, alice, '4.50', line: 3) # works only because line 2 ran first
      ]
    end

    it 'returns one result per transfer, in file order' do
      results = process_transfers.call(requests)

      expect(results.map { |result| result.request.line }).to eq([1, 2, 3])
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
