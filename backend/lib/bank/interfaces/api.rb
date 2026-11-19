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
    # The accounts live in memory, so balances carry over from one request to
    # the next and go back to their starting values when the server restarts.
    class Api < Sinatra::Base
      # Requests can be handled at the same time. Two uploads processed at
      # the same moment could both spend the same balance, so this lock makes
      # them run one after the other.
      ONE_AT_A_TIME = Mutex.new

      # Reads the balances file into memory. Called once, at startup. A bad
      # file raises an error, so the server does not start.
      def self.load_balances(path)
        accounts = Infrastructure::InMemoryAccountRepository.new
        rows = Infrastructure::CsvFiles.opening_balances(File.read(path))
        Application::LoadAccounts.new(accounts: accounts).call(rows)
        set :accounts, accounts
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
