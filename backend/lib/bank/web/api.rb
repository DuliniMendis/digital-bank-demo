# frozen_string_literal: true

require 'json'
require 'sinatra/base'

module Bank
  module Web
    # The HTTP API. It contains no business logic: each route reads the
    # request, calls a use case and returns the result as JSON.
    #
    #   GET  /api/accounts    the current balance of every account
    #   POST /api/transfers   applies a transfers CSV, uploaded as form field "file"
    #   GET  /api/transfers   every transfer from every uploaded file
    #   POST /api/reset       back to the opening balances, with no history
    #
    # Accounts and history are kept in Postgres, so they are still there
    # after the server restarts.
    class Api < Sinatra::Base
      # Called once from config.ru, before the server accepts any request.
      #
      # `set` stores a value on the app, and the routes read it back through
      # `settings`. The balances file is only loaded when the database has
      # no accounts yet, which is the first start. Later starts keep the
      # balances the database already holds.
      def self.start(database:, balances_file:)
        set :accounts, Infrastructure::PostgresAccountRepository.new(database)
        set :history, Infrastructure::PostgresTransferHistory.new(database)
        set :opening_balances, Infrastructure::CsvFiles.opening_balances(File.read(balances_file))
        reset if accounts.all.empty?
      end

      # A bad balances file raises an error here. On the first start that
      # stops the server from starting.
      def self.reset
        UseCases::Reset.new(accounts: accounts, history: history).call(opening_balances)
      end

      get '/api/accounts' do
        json(accounts: accounts_as_json)
      end

      get '/api/transfers' do
        json(transfers: settings.history.all.map { |recorded| recorded_transfer_as_json(recorded) })
      end

      post '/api/transfers' do
        # Sinatra exposes an uploaded file as a Hash with a :tempfile entry.
        # `csv` is nil when no file was sent.
        csv = params.dig(:file, :tempfile)&.read
        halt 400, json(error: 'Send the transfers CSV as a form field called "file".') unless csv

        results = apply(csv, apply_again: params[:apply_again] == 'true')
        json(transfers: results.map { |result| transfer_as_json(result) }, accounts: accounts_as_json)
      rescue CSV::MalformedCSVError => e
        halt 400, json(error: "The file is not valid CSV: #{e.message}")
      rescue UseCases::TransfersAlreadyApplied => e
        # 409 Conflict: the request is fine, but it clashes with what the
        # server already holds.
        halt 409, json(error: "#{e.message} Send it with apply_again=true to apply it a second time.")
      end

      post '/api/reset' do
        self.class.reset
        json(accounts: accounts_as_json)
      end

      # Without this, an unknown address gets Sinatra's HTML error page.
      not_found do
        json(error: 'There is nothing at this address.')
      end

      helpers do
        def json(data)
          content_type :json
          JSON.generate(data)
        end

        def apply(csv, apply_again:)
          UseCases::ApplyTransfersFile.new(accounts: settings.accounts, history: settings.history).call(
            fingerprint: Infrastructure::CsvFiles.fingerprint(csv),
            requests: Infrastructure::CsvFiles.transfer_requests(csv),
            apply_again: apply_again
          )
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

        # `iso8601` writes the time in the standard form that JavaScript's
        # `new Date(...)` reads, for example "2026-11-19T14:02:11+11:00".
        def recorded_transfer_as_json(recorded)
          transfer_as_json(recorded.result).merge(uploaded_at: recorded.uploaded_at.iso8601)
        end
      end
    end
  end
end
