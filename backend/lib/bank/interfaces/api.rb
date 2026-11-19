# frozen_string_literal: true

require 'json'
require 'sinatra/base'

module Bank
  module Interfaces
    # The HTTP API. It contains no business logic: each route reads the
    # request, calls an application service and returns the result as JSON.
    #
    #   GET  /accounts    the current balance of every account
    #   POST /transfers   applies a transfers CSV, uploaded as form field "file"
    #
    # The accounts are kept in Postgres, so balances are still there after
    # the server restarts. The server never loads balances itself: the
    # database is filled by seeding it.
    class Api < Sinatra::Base
      # Tells the app which database to use. Called once, at startup.
      def self.start(database:)
        set :accounts, Infrastructure::AccountRepository.new(database)
      end

      get '/accounts' do
        json(accounts: accounts_as_json)
      end

      post '/transfers' do
        # Sinatra exposes an uploaded file as a Hash with a :tempfile entry.
        # `csv` is nil when no file was sent.
        csv = params.dig(:file, :tempfile)&.read
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

        def process(requests)
          Application::ProcessTransfers.new(accounts: settings.accounts).call(requests)
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
