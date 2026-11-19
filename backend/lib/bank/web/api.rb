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
    class Api < Sinatra::Base
      # The server handles requests on several threads. Two uploads processed
      # at the same moment could both spend the same balance, so this lock
      # makes them run one after the other.
      ONE_AT_A_TIME = Mutex.new

      # Called once from config.ru, before the server accepts any request. A
      # bad balances file raises an error here, which stops the server from
      # starting.
      #
      # `set :accounts` stores the repository on the app. The routes read it
      # back as `settings.accounts`.
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
          UseCases::ProcessTransfers.new(accounts: settings.accounts).call(requests)
        end

        # Balances are sent as strings such as "4820.50". As JSON numbers
        # they would be read as floats by most clients, which can be a cent
        # out.
        def accounts_as_json
          settings.accounts.all.map do |account|
            { number: account.number.to_s, balance: account.balance.to_s }
          end
        end

        # The fields of the original request (line, from, to, amount) plus
        # what happened to it.
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
