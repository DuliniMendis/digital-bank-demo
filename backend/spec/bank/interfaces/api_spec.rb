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
    described_class.start(
      database: database,
      balances_file: fixture_path('account_balances.csv'),
      sample_files: [fixture_path('transfers.csv'), fixture_path('edge_cases/all_rejected_wrong_columns.csv')]
    )
    described_class.reseed
  end

  def fixture_path(name)
    File.expand_path("../../fixtures/#{name}", __dir__)
  end

  # Uploads the CSV text as a file in a form field called "file", the same
  # way `curl -F file=@transfers.csv` does.
  # Any `other_fields` are sent as plain form fields beside the file, the
  # way a second `-F` does with curl.
  def post_transfers(csv_text, **other_fields)
    file = Rack::Test::UploadedFile.new(StringIO.new(csv_text), 'text/csv', original_filename: 'transfers.csv')
    post '/api/transfers', file: file, **other_fields
  end

  def body
    JSON.parse(last_response.body)
  end

  def balances
    get '/api/accounts'
    body['accounts'].to_h { |account| [account['number'], account['balance']] }
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

    it 'rejects a line that contains an accented character' do
      post_transfers("1111234522226789,1212343433335665,5é\n")

      expect(body['transfers'].first).to include('status' => 'rejected', 'amount' => '5é')
    end

    # The first line sends $600.00 from an account that holds $550.00, and
    # the second line pays that account $100.00.
    context 'with a transfer that a later line pays for' do
      let(:csv) { "2222123433331212,1212343433335665,600.00\n1212343433335665,2222123433331212,100.00\n" }

      it 'rejects it by default' do
        post_transfers(csv)

        expect(body['transfers'].map { |transfer| transfer['status'] }).to eq(%w[rejected completed])
      end

      it 'completes it when the upload asks to settle at the end' do
        post_transfers(csv, settle_at_end: 'true')

        expect(body['transfers'].map { |transfer| transfer['status'] }).to eq(%w[completed completed])
      end

      it 'saves the settled balances' do
        post_transfers(csv, settle_at_end: 'true')

        expect(balances.values_at('2222123433331212', '1212343433335665')).to eq(['50.00', '1700.00'])
      end
    end

    it 'keeps the balances between one post and the next' do
      2.times { post_transfers(pay_one_hundred) }

      expect(balances['1111234522226789']).to eq('4800.00')
    end

    it 'answers 400 when no file is sent' do
      post '/api/transfers'

      expect(last_response.status).to eq(400)
    end

    it 'answers 400 when "file" is sent as text and not as a file' do
      post '/api/transfers', file: "1111234522226789,1212343433335665,1.00\n"

      expect(last_response.status).to eq(400)
    end

    it 'answers 400 when the file is not valid CSV' do
      post_transfers(%("unclosed,quote\n))

      expect(last_response.status).to eq(400)
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

  describe 'GET /api/samples' do
    it 'lists the names of the sample files, in the order they were given' do
      get '/api/samples'

      expect(body['samples']).to eq(['transfers.csv', 'all_rejected_wrong_columns.csv'])
    end
  end

  describe 'GET /api/samples/:name' do
    it 'sends the sample file with that name' do
      get '/api/samples/all_rejected_wrong_columns.csv'

      expect(last_response.body).to eq(File.read(fixture_path('edge_cases/all_rejected_wrong_columns.csv')))
    end

    it 'sends it as a download with the same name' do
      get '/api/samples/transfers.csv'

      expect(last_response.headers['content-disposition']).to eq('attachment; filename="transfers.csv"')
    end

    it 'answers 404 for a file that is not one of the samples' do
      get '/api/samples/account_balances.csv'

      expect(last_response.status).to eq(404)
    end
  end

  describe 'an address that does not exist' do
    it 'answers 404 with a JSON error' do
      get '/api/nothing'

      expect([last_response.status, body]).to match([404, { 'error' => a_string_including('nothing') }])
    end
  end
end
