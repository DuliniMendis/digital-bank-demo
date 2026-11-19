# frozen_string_literal: true

RSpec.describe Bank::Infrastructure::CsvFiles do
  describe '.opening_balances' do
    it 'reads the account number and balance from each line' do
      rows = described_class.opening_balances("1111234522226789,5000.00\n")

      expect(rows.first.to_h).to eq(line: 1, number: '1111234522226789', balance: '5000.00')
    end

    it 'numbers the lines from one' do
      rows = described_class.opening_balances("1111234522226789,1\n1111234522221234,2\n")

      expect(rows.map(&:line)).to eq([1, 2])
    end

    it 'skips blank lines but keeps the real line numbers' do
      rows = described_class.opening_balances("1111234522226789,1\n\n1111234522221234,2\n")

      expect(rows.map(&:line)).to eq([1, 3])
    end

    it 'leaves a missing column empty for the domain to reject' do
      rows = described_class.opening_balances("1111234522226789\n")

      expect(rows.first.balance).to be_nil
    end

    it 'returns nothing for an empty file' do
      expect(described_class.opening_balances('')).to be_empty
    end
  end

  describe '.transfer_requests' do
    it 'reads from, to and amount from each line' do
      rows = described_class.transfer_requests("1111234522226789,1212343433335665,500.00\n")

      expect(rows.first.to_h).to eq(
        line: 1, from: '1111234522226789', to: '1212343433335665', amount: '500.00'
      )
    end

    it 'keeps the lines in file order' do
      text = "1111234522226789,1212343433335665,1\n3212343433335755,2222123433331212,2\n"

      expect(described_class.transfer_requests(text).map(&:amount)).to eq(%w[1 2])
    end

    it 'reads files with Windows line endings' do
      rows = described_class.transfer_requests("1111234522226789,1212343433335665,5.00\r\n")

      expect(rows.first.amount).to eq('5.00')
    end
  end

  describe 'a file that is not valid CSV' do
    it 'raises UnreadableCsv' do
      expect { described_class.transfer_requests(%("unclosed,quote\n)) }
        .to raise_error(Bank::Infrastructure::UnreadableCsv)
    end
  end
end
