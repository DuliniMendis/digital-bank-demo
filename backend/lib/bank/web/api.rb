# frozen_string_literal: true

require 'json'
require 'sinatra/base'

module Bank
  module Web
    # The HTTP API. No business logic here: read the request, call a use
    # case, return JSON.
    #
    #   GET  /accounts    current balances
    #   POST /transfers   apply a transfers CSV, sent as form field "file"
    class Api < Sinatra::Base
      # Two uploads handled at the same moment could both spend the same
      # balance, so they are processed one at a time.
      ONE_AT_A_TIME = Mutex.new

      # Called once from config.ru. A bad file raises, so the server won't
      # start on balances it couldn't read.
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

        # Balances go out as strings ("4820.50") so JSON can't round them.
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
