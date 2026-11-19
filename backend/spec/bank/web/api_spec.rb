# frozen_string_literal: true

require 'rack/test'
require 'stringio'

# End-to-end: real HTTP requests in, JSON out. The "sample files" context is
# the check of the original challenge.
RSpec.describe Bank::Web::Api do
  include Rack::Test::Methods

  # Rack::Test sends its requests to whatever `app` returns.
  def app
    described_class
  end

  # Every example starts from the sample balances file, as a fresh server
  # start would.
  before { described_class.load_balances(fixture_path('account_balances.csv')) }

  def fixture_path(name)
    File.expand_path("../../fixtures/#{name}", __dir__)
  end

  # Posts CSV text to /transfers the way `curl -F file=@transfers.csv` does.
  def post_transfers(csv_text)
    file = Rack::Test::UploadedFile.new(StringIO.new(csv_text), 'text/csv', original_filename: 'transfers.csv')
    post '/transfers', file: file
  end

  def body
    JSON.parse(last_response.body)
  end

  def balances
    body['accounts'].to_h { |account| [account['number'], account['balance']] }
  end

  describe 'GET /accounts' do
    it 'lists the balances loaded at startup, in file order' do
      get '/accounts'

      expect(body['accounts'].first).to eq('number' => '1111234522226789', 'balance' => '5000.00')
    end
  end

  describe 'POST /transfers' do
    context 'with the sample transfers file' do
      let(:expected_balances) do
        {
          '1111234522226789' => '4820.50',
          '1111234522221234' => '9974.40',
          '2222123433331212' => '1550.00',
          '1212343433335665' => '1725.60',
          '3212343433335755' => '48679.50'
        }
      end

      before { post_transfers(File.read(fixture_path('transfers.csv'))) }

      it 'completes all four transfers' do
        expect(body['transfers'].map { |transfer| transfer['status'] }).to eq(['completed'] * 4)
      end

      it 'leaves every account with the expected balance' do
        expect(balances).to eq(expected_balances)
      end
    end

    it 'reports a rejected transfer with its line and the reason' do
      post_transfers("1111234522226789,1212343433335665,5000.01\n")

      expect(body['transfers'].first).to include(
        'line' => 1, 'status' => 'rejected',
        'reason' => 'account 1111234522226789 does not have sufficient funds to withdraw $5000.01'
      )
    end

    it 'keeps the balances between one post and the next' do
      2.times { post_transfers("1111234522226789,1212343433335665,100.00\n") }

      expect(balances['1111234522226789']).to eq('4800.00')
    end

    it 'answers 400 when no file is sent' do
      post '/transfers'

      expect(last_response.status).to eq(400)
    end

    it 'answers 400 when the file is not valid CSV' do
      post_transfers(%("unclosed,quote\n))

      expect(last_response.status).to eq(400)
    end
  end

  describe 'handling two files that arrive together' do
    # Stands in for ProcessTransfers and notices if two calls overlap.
    let(:slow_processor) do
      Class.new do
        attr_reader :overlapped

        def call(_requests)
          @overlapped ||= @busy
          @busy = true
          sleep 0.05
          @busy = false
          []
        end
      end.new
    end

    it 'processes one at a time' do
      allow(Bank::UseCases::ProcessTransfers).to receive(:new).and_return(slow_processor)

      Array.new(2) { Thread.new { post_transfers('') } }.each(&:join)

      expect(slow_processor.overlapped).to be_falsy
    end
  end

  describe '.load_balances' do
    it 'refuses a bad balances file, so the server cannot start with it' do
      bad_file = Tempfile.create(['balances', '.csv']).tap { |file| file.write("12345,1.00\n") }.tap(&:close)

      expect { described_class.load_balances(bad_file.path) }
        .to raise_error(Bank::UseCases::InvalidOpeningBalances, /line 1/)
    end
  end
end
