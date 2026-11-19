# frozen_string_literal: true

require 'json'
require 'sinatra/base'

module Bank
  module Web
    # The HTTP API. It contains no business logic: each route reads the
    # request, calls a use case and returns the result as JSON.
    #
    #   GET  /accounts    the current balance of every account
    #   POST /transfers   applies a transfers CSV, uploaded as form field "file"
    #
    # The accounts live in memory, so balances carry over from one request to
    # the next and go back to their starting values when the server restarts.
    #
    # Nothing here stops two uploads from being processed at the same moment.
    # The `extended` branch does that with database transactions and locks.
    class Api < Sinatra::Base
      # Reads the balances file into memory. Called once, at startup. A bad
      # file raises an error, so the server does not start.
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
        csv = uploaded_csv
        halt 400, json(error: 'Send the transfers CSV as a form field called "file".') unless csv

        requests = Infrastructure::CsvFiles.transfer_requests(csv)
        results = process(requests)
        json(transfers: results.map { |result| transfer_as_json(result) }, accounts: accounts_as_json)
      rescue CSV::MalformedCSVError => e
        halt 400, json(error: "The file is not valid CSV: #{e.message}")
      end

      helpers do
        def json(data)
          content_type :json
          JSON.generate(data)
        end

        # Sinatra exposes an uploaded file as a Hash with a :tempfile entry.
        # The "file" field is missing when nothing was sent, and is a plain
        # String when it was sent as text and not as a file. Both give nil.
        def uploaded_csv
          file = params[:file]
          file[:tempfile]&.read if file.is_a?(Hash)
        end

        def process(requests)
          UseCases::ProcessTransfers.new(accounts: settings.accounts).call(requests)
        end

        # Balances are sent as strings such as "4820.50". A JSON number would
        # become a float in most clients, and any sums done with it could
        # drift by a fraction of a cent.
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
