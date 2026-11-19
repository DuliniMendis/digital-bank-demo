# frozen_string_literal: true

require 'rack/test'
require 'stringio'

RSpec.describe Bank::Interfaces::Api, :database do
  include Rack::Test::Methods

  # Rack::Test sends its requests to whatever `app` returns.
  def app
    described_class
  end

  # Every example begins with an empty database, so each one seeds it with
  # the sample balances first.
  before do
    described_class.start(database: database, balances_file: fixture_path('account_balances.csv'))
    described_class.reseed
  end

  def fixture_path(name)
    File.expand_path("../../fixtures/#{name}", __dir__)
  end

  # Uploads the CSV text as a file in a form field called "file", the same
  # way `curl -F file=@transfers.csv` does.
  def post_transfers(csv_text, **fields)
    file = Rack::Test::UploadedFile.new(StringIO.new(csv_text), 'text/csv', original_filename: 'transfers.csv')
    post '/api/transfers', file: file, **fields
  end

  def body
    JSON.parse(last_response.body)
  end

  def balances
    get '/api/accounts'
    body['accounts'].to_h { |account| [account['number'], account['balance']] }
  end

  def history
    get '/api/transfers'
    body['transfers']
  end

  let(:pay_one_hundred) { "1111234522226789,1212343433335665,100.00\n" }

  describe 'GET /api/accounts' do
    it 'lists the balances the database was seeded with' do
      get '/api/accounts'

      expect(body['accounts'].first).to eq('number' => '1111234522226789', 'balance' => '5000.00')
    end
  end

  describe 'POST /api/transfers' do
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

    it 'keeps the balances between one file and the next' do
      post_transfers(pay_one_hundred)
      post_transfers("1111234522226789,1212343433335665,50.00\n")

      expect(balances['1111234522226789']).to eq('4850.00')
    end

    it 'answers 400 when no file is sent' do
      post '/api/transfers'

      expect(last_response.status).to eq(400)
    end

    it 'answers 400 when the file is not valid CSV' do
      post_transfers(%("unclosed,quote\n))

      expect(last_response.status).to eq(400)
    end
  end

  describe 'posting the same transfers file twice' do
    before { post_transfers(pay_one_hundred) }

    it 'answers 409 and says the file was already applied' do
      post_transfers(pay_one_hundred)

      expect([last_response.status, body['error']]).to match([409, /already been applied/])
    end

    it 'does not move the money a second time' do
      post_transfers(pay_one_hundred)

      expect(balances['1111234522226789']).to eq('4900.00')
    end

    it 'applies it again when apply_again is true' do
      post_transfers(pay_one_hundred, apply_again: 'true')

      expect(balances['1111234522226789']).to eq('4800.00')
    end
  end

  describe 'GET /api/transfers' do
    before { post_transfers("#{pay_one_hundred}1111234522226789,9999999999999999,1.00\n") }

    it 'lists a completed transfer with the time of the upload' do
      expect(history.first).to include(
        'line' => 1, 'amount' => '100.00', 'status' => 'completed', 'uploaded_at' => /\A\d{4}-\d\d-\d\dT/
      )
    end

    it 'lists a rejected transfer with the reason' do
      expect(history.last).to include(
        'line' => 2, 'status' => 'rejected', 'reason' => 'account 9999999999999999 does not exist'
      )
    end
  end

  describe 'POST /api/reset' do
    before do
      post_transfers(pay_one_hundred)
      post '/api/reset'
    end

    it 'puts the balances back to the balances file' do
      expect(balances['1111234522226789']).to eq('5000.00')
    end

    it 'empties the history, so the same file can be applied again' do
      expect(history).to be_empty
    end
  end

  describe 'POST /api/reset on a database that was never seeded' do
    before do
      database[:accounts].delete
      post '/api/reset'
    end

    it 'seeds it from the balances file' do
      expect(balances['1111234522226789']).to eq('5000.00')
    end
  end

  describe 'an address that does not exist' do
    it 'answers 404 with a JSON error' do
      get '/api/nothing'

      expect([last_response.status, body]).to match([404, { 'error' => a_string_including('nothing') }])
    end
  end
end
