# frozen_string_literal: true

require 'json'
require 'sinatra/base'

module Bank
  module Web
    # Api is the HTTP entry point. It holds no business rules: it reads the
    # request, calls a use case, and turns the result into JSON.
    #
    #   GET  /accounts    the current balance of every account
    #   POST /transfers   apply a day's transfers, sent as a CSV file
    #
    # The balances are loaded once, when the server starts, and kept in
    # memory. Restarting the server puts every account back to its starting
    # balance.
    class Api < Sinatra::Base
      # Only one transfers file is processed at a time. Without this, two
      # files arriving together could both spend the same balance.
      ONE_AT_A_TIME = Mutex.new

      # Reads the balances file into memory. Called once, at startup, from
      # config.ru. A bad file raises an error, so the server does not start.
      def self.load_balances(path)
        accounts = Infrastructure::InMemoryAccountRepository.new
        rows = Infrastructure::CsvFiles.opening_balances(File.read(path))
        UseCases::LoadAccounts.new(accounts: accounts).call(rows)
        set :accounts, accounts
      end

      get '/accounts' do
        json(accounts: accounts_as_json)
      end

      post '/transfers' do
        halt 400, json(error: 'Send the transfers CSV as a form field called "file".') unless uploaded_csv

        requests = Infrastructure::CsvFiles.transfer_requests(uploaded_csv)
        results = ONE_AT_A_TIME.synchronize { process(requests) }
        json(transfers: results.map { |result| transfer_as_json(result) }, accounts: accounts_as_json)
      rescue CSV::MalformedCSVError => e
        halt 400, json(error: "The file is not valid CSV: #{e.message}")
      end

      helpers do
        def json(data)
          content_type :json
          JSON.generate(data)
        end

        # The text of the uploaded file, or nil if none was sent.
        def uploaded_csv
          @uploaded_csv ||= params.dig(:file, :tempfile)&.read
        end

        def process(requests)
          UseCases::ProcessTransfers.new(accounts: settings.accounts).call(requests)
        end

        # Balances are sent as text such as "4820.50", so no precision is
        # lost on the way to the client.
        def accounts_as_json
          settings.accounts.all.map do |account|
            { number: account.number.to_s, balance: account.balance.to_s }
          end
        end

        def transfer_as_json(result)
          result.request.to_h.merge(
            status: result.completed? ? 'completed' : 'rejected',
            reason: result.rejection_reason
          )
        end
      end
    end
  end
end
