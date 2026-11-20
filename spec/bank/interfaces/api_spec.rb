# frozen_string_literal: true

require 'rack/test'
require 'stringio'

RSpec.describe Bank::Interfaces::Api do
  include Rack::Test::Methods

  # Rack::Test sends its requests to whatever `app` returns.
  def app
    described_class
  end

  # Loading the balances again before each example gives every example the
  # same starting point, as if the server had just been started.
  before { described_class.load_balances(fixture_path('account_balances.csv')) }

  def fixture_path(name)
    File.expand_path("../../fixtures/#{name}", __dir__)
  end

  # Uploads the CSV text as a file in a form field called "file", the same
  # way `curl -F file=@transfers.csv` does.
  # Any `other_fields` are sent as plain form fields beside the file, the
  # way a second `-F` does with curl.
  def post_transfers(csv_text, **other_fields)
    file = Rack::Test::UploadedFile.new(StringIO.new(csv_text), 'text/csv', original_filename: 'transfers.csv')
    post '/transfers', file: file, **other_fields
  end

  def body
    JSON.parse(last_response.body)
  end

  def balances
    body['accounts'].to_h { |account| [account['number'], account['balance']] }
  end

  describe 'GET /accounts' do
    it 'lists the balances loaded at startup' do
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
    end

    it 'keeps the balances between one post and the next' do
      2.times { post_transfers("1111234522226789,1212343433335665,100.00\n") }

      expect(balances['1111234522226789']).to eq('4800.00')
    end

    it 'answers 400 when no file is sent' do
      post '/transfers'

      expect(last_response.status).to eq(400)
    end

    it 'answers 400 when "file" is sent as text and not as a file' do
      post '/transfers', file: "1111234522226789,1212343433335665,1.00\n"

      expect(last_response.status).to eq(400)
    end

    it 'answers 400 when the file is not valid CSV' do
      post_transfers(%("unclosed,quote\n))

      expect(last_response.status).to eq(400)
    end
  end
end
