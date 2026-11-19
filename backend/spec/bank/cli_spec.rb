# frozen_string_literal: true

require 'open3'
require 'stringio'
require 'tempfile'

# End-to-end: real files in, printed report out.
RSpec.describe Bank::CLI do
  subject(:cli) { described_class.new(out: out, err: err) }

  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:balances_path) { File.expand_path('../../examples/account_balances.csv', __dir__) }
  let(:transfers_path) { File.expand_path('../../examples/transfers.csv', __dir__) }

  # Writes text to a temporary CSV file and returns its path.
  def csv_file(text)
    file = Tempfile.new(['spec', '.csv'])
    file.write(text)
    file.close
    file.path
  end

  context 'with the sample files' do
    {
      '1111234522226789' => '4820.50',
      '1111234522221234' => '9974.40',
      '2222123433331212' => '1550.00',
      '1212343433335665' => '1725.60',
      '3212343433335755' => '48679.50'
    }.each do |number, balance|
      it "leaves account #{number} with #{balance}" do
        cli.run([balances_path, transfers_path])

        expect(out.string).to match(/^  #{number}\s+#{Regexp.escape(balance)}$/)
      end
    end

    it 'reports that all four transfers completed' do
      cli.run([balances_path, transfers_path])

      expect(out.string).to include('Transfers: 4 completed, 0 rejected')
    end

    it 'has no rejected section' do
      cli.run([balances_path, transfers_path])

      expect(out.string).not_to include('Rejected transfers')
    end

    it 'exits with success' do
      expect(cli.run([balances_path, transfers_path])).to eq(0)
    end
  end

  context 'when a transfer is rejected' do
    let(:transfers_path) { csv_file("1111234522226789,1212343433335665,5000.01\n") }

    it 'lists it with its line number and the reason' do
      cli.run([balances_path, transfers_path])

      expect(out.string).to include(
        'line 1: 1111234522226789 -> 1212343433335665 5000.01: ' \
        'account 1111234522226789 does not have sufficient funds to withdraw $5000.01'
      )
    end

    it 'counts it in the summary' do
      cli.run([balances_path, transfers_path])

      expect(out.string).to include('Transfers: 0 completed, 1 rejected')
    end

    it 'still exits with success, because a rejection is a normal outcome' do
      expect(cli.run([balances_path, transfers_path])).to eq(0)
    end
  end

  context 'when the balances file has a bad line' do
    let(:balances_path) { csv_file("1111234522226789,5000.00\n12345,10.00\n") }

    it 'prints the line number and the reason' do
      cli.run([balances_path, transfers_path])

      expect(err.string).to match(/Error: line 2: .*16 digit account number/)
    end

    it 'exits with failure' do
      expect(cli.run([balances_path, transfers_path])).to eq(1)
    end

    it 'prints no balances' do
      cli.run([balances_path, transfers_path])

      expect(out.string).to be_empty
    end
  end

  context 'when a file does not exist' do
    it 'prints an error' do
      cli.run([balances_path, 'no_such_file.csv'])

      expect(err.string).to include('Error: No such file or directory')
    end

    it 'exits with failure' do
      expect(cli.run([balances_path, 'no_such_file.csv'])).to eq(1)
    end
  end

  context 'when the wrong number of arguments is given' do
    it 'prints how to use the command' do
      cli.run([balances_path])

      expect(err.string).to include('Usage: bin/process_transfers')
    end

    it 'exits with failure' do
      expect(cli.run([])).to eq(1)
    end
  end

  describe 'the bin/process_transfers script' do
    it 'runs from the command line and prints the final balances' do
      script = File.expand_path('../../bin/process_transfers', __dir__)
      output, = Open3.capture2(script, balances_path, transfers_path)

      expect(output).to include('3212343433335755      48679.50')
    end
  end
end
