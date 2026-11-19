# frozen_string_literal: true

require 'json'
require 'sinatra/base'

module Bank
  module Interfaces
    # The HTTP API. It contains no business logic: each route reads the
    # request, calls an application service and returns the result as JSON.
    #
    #   GET  /api/accounts    the current balance of every account
    #   POST /api/transfers   applies a transfers CSV, uploaded as form field "file"
    #   GET  /api/transfers   every transfer from every uploaded file
    #   POST /api/reset       reseeds: opening balances again, and no history
    #
    # Accounts and history are kept in Postgres, so they are still there
    # after the server restarts. The server never loads balances when it
    # starts: the database is filled by seeding it.
    class Api < Sinatra::Base
      # Tells the app which database to use, and which balances file a reset
      # goes back to. Called once, at startup.
      def self.start(database:, balances_file:)
        set :accounts, Infrastructure::AccountRepository.new(database)
        set :history, Infrastructure::TransferHistory.new(database)
        set :balances_file, balances_file
      end

      # Empties the database and loads the balances file into it again.
      def self.reseed
        opening_balances = Infrastructure::CsvFiles.opening_balances(File.read(balances_file))
        Application::SeedAccounts.new(accounts: accounts, history: history).call(opening_balances)
      end

      get '/api/accounts' do
        json(accounts: accounts_as_json)
      end

      get '/api/transfers' do
        json(transfers: settings.history.all.map { |recorded| recorded_transfer_as_json(recorded) })
      end

      post '/api/transfers' do
        csv = uploaded_csv
        halt 400, json(error: 'Send the transfers CSV as a form field called "file".') unless csv

        results = apply(csv, apply_again: params[:apply_again] == 'true')
        json(transfers: results.map { |result| transfer_as_json(result) }, accounts: accounts_as_json)
      rescue CSV::MalformedCSVError => e
        halt 400, json(error: "The file is not valid CSV: #{e.message}")
      rescue Application::TransfersAlreadyApplied => e
        # 409 Conflict: the request is fine, but it clashes with what the
        # server already holds.
        halt 409, json(error: "#{e.message} Send it with apply_again=true to apply it a second time.")
      end

      post '/api/reset' do
        self.class.reseed
        json(accounts: accounts_as_json)
      end

      # An unknown address gets a JSON error, like every other failure.
      not_found do
        json(error: 'There is nothing at this address.')
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

        def apply(csv, apply_again:)
          Application::ProcessTransfers.new(accounts: settings.accounts, history: settings.history).call(
            Infrastructure::CsvFiles.transfer_requests(csv),
            fingerprint: Infrastructure::CsvFiles.fingerprint(csv),
            apply_again: apply_again
          )
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

        # The upload time is sent in ISO 8601 form, for example
        # "2026-11-19T14:02:11+11:00".
        def recorded_transfer_as_json(recorded)
          transfer_as_json(recorded.result).merge(uploaded_at: recorded.uploaded_at.iso8601)
        end
      end
    end
  end
end
