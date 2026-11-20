# frozen_string_literal: true

require 'json'
require 'sinatra/base'

module Bank
  module Interfaces
    # The HTTP API. It contains no business logic: each route reads the
    # request, calls an application service and returns the result as JSON.
    #
    #   GET  /api/accounts        the current balance of every account
    #   POST /api/transfers       applies a transfers CSV, uploaded as form field "file"
    #   POST /api/reset           reseeds: puts the opening balances back
    #   GET  /api/samples         the names of the sample transfers files
    #   GET  /api/samples/:name   one sample transfers file, as a download
    #
    # Adding the form field `settle_at_end=true` to an upload checks the
    # balances once, after the whole file, and not after every line.
    #
    # The accounts are kept in Postgres, so balances are still there after
    # the server restarts. The server never loads balances when it starts:
    # the database is filled by seeding it.
    class Api < Sinatra::Base
      # Tells the app which database to use, which balances file a reset
      # goes back to, and which transfers files it offers as samples. Called
      # once, at startup.
      #
      # The samples are kept as a Hash from each file's name to its path. A
      # request can then only ever name a file that is in the Hash, never
      # some other file on the server.
      def self.start(database:, balances_file:, sample_files:)
        set :accounts, Infrastructure::AccountRepository.new(database)
        set :balances_file, balances_file
        names_to_paths = sample_files.to_h { |path| [File.basename(path), path] }
        set :sample_files, names_to_paths
      end

      # Removes the accounts and loads the balances file into the database
      # again.
      def self.reseed
        opening_balances = Infrastructure::CsvFiles.opening_balances(File.read(balances_file))
        Application::SeedAccounts.new(accounts: accounts).call(opening_balances)
      end

      get '/api/accounts' do
        json(accounts: accounts_as_json)
      end

      post '/api/transfers' do
        csv = uploaded_csv
        halt 400, json(error: 'Send the transfers CSV as a form field called "file".') unless csv

        requests = Infrastructure::CsvFiles.transfer_requests(csv)
        results = process(requests)
        json(transfers: results.map { |result| transfer_as_json(result) }, accounts: accounts_as_json)
      rescue CSV::MalformedCSVError => e
        halt 400, json(error: "The file is not valid CSV: #{e.message}")
      end

      post '/api/reset' do
        self.class.reseed
        json(accounts: accounts_as_json)
      end

      # The page offers these files to try. Serving them from here means the
      # page needs no copies of its own that could drift from the files the
      # specs use.
      get '/api/samples' do
        json(samples: settings.sample_files.keys)
      end

      get '/api/samples/:name' do
        path = settings.sample_files[params[:name]]
        halt 404 unless path

        send_file path, type: :csv, disposition: 'attachment'
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

        def process(requests)
          Application::ProcessTransfers.new(accounts: settings.accounts)
                                       .call(requests, settle_at_end: params[:settle_at_end] == 'true')
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
