# frozen_string_literal: true

module Bank
  # CLI is the command-line entry point:
  #
  #   bin/process_transfers BALANCES_CSV TRANSFERS_CSV
  #
  # It only connects the pieces: read the files, run the use cases, print
  # the report. It holds no business rules of its own.
  class CLI
    USAGE = 'Usage: bin/process_transfers BALANCES_CSV TRANSFERS_CSV'

    # Problems with the input that should print a message, not a stack trace.
    INPUT_ERRORS = [
      UseCases::InvalidOpeningBalances,
      Infrastructure::UnreadableCsv,
      SystemCallError # for example, a file that does not exist
    ].freeze

    def initialize(out: $stdout, err: $stderr)
      @out = out
      @err = err
    end

    # Returns the exit code for the process: 0 for success, 1 for failure.
    # Rejected transfers are a normal outcome, so they still return 0.
    def run(args)
      return fail_with(USAGE) unless args.size == 2

      accounts = Infrastructure::InMemoryAccountRepository.new
      load_accounts(accounts, args[0])
      results = process_transfers(accounts, args[1])
      @out.puts Report.new(accounts: accounts.all, results: results)
      0
    rescue *INPUT_ERRORS => e
      fail_with("Error: #{e.message}")
    end

    private

    def load_accounts(accounts, path)
      rows = Infrastructure::CsvFiles.opening_balances(File.read(path))
      UseCases::LoadAccounts.new(accounts: accounts).call(rows)
    end

    def process_transfers(accounts, path)
      rows = Infrastructure::CsvFiles.transfer_requests(File.read(path))
      UseCases::ProcessTransfers.new(accounts: accounts).call(rows)
    end

    def fail_with(message)
      @err.puts message
      1
    end
  end
end
