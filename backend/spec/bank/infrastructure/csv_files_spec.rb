# frozen_string_literal: true

RSpec.describe Bank::Infrastructure::CsvFiles do
  describe '.opening_balances' do
    it 'reads the account number and balance from a line' do
      rows = described_class.opening_balances("1111234522226789,5000.00\n")

      expect(rows.first.to_h).to eq(line: 1, number: '1111234522226789', balance: '5000.00')
    end
  end

  describe '.transfer_requests' do
    it 'reads from, to and amount from a line' do
      rows = described_class.transfer_requests("1111234522226789,1212343433335665,500.00\n")

      expect(rows.first.to_h).to eq(
        line: 1, from: '1111234522226789', to: '1212343433335665', amount: '500.00'
      )
    end

    it 'skips blank lines but keeps the real line numbers' do
      text = "1111234522226789,1212343433335665,1\n\n3212343433335755,2222123433331212,2\n"

      expect(described_class.transfer_requests(text).map(&:line)).to eq([1, 3])
    end

    it 'skips a header row but keeps the real line numbers' do
      text = "From,To,Amount\n1111234522226789,1212343433335665,5.00\n"

      expect(described_class.transfer_requests(text).map(&:line)).to eq([2])
    end

    it 'does not mistake a mistyped account number on the first line for a header' do
      rows = described_class.transfer_requests("11112345X2226789,1212343433335665,5.00\n")

      expect(rows.map(&:from)).to eq(['11112345X2226789'])
    end

    it 'leaves a missing column empty for the domain to reject' do
      rows = described_class.transfer_requests("1111234522226789,1212343433335665\n")

      expect(rows.first.amount).to be_nil
    end

    it 'ignores a byte-order mark at the start of the file' do
      rows = described_class.transfer_requests("\uFEFF1111234522226789,1212343433335665,1\n")

      expect(rows.first.from).to eq('1111234522226789')
    end

    # `.b` gives the text as raw bytes, which is how an upload arrives.
    it 'reads the raw bytes of an upload as UTF-8' do
      rows = described_class.transfer_requests("1111234522226789,1212343433335665,5é\n".b)

      expect(rows.first.amount).to eq('5é')
    end

    it 'replaces a byte that is not valid UTF-8' do
      rows = described_class.transfer_requests("1111234522226789,1212343433335665,5\xFF\n".b)

      expect(rows.first.amount).to eq("5\uFFFD")
    end
  end
end
