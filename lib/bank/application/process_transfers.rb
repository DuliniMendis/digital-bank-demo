# frozen_string_literal: true

module Bank
  module Application
    # One line of the transfers file: its line number and the three fields
    # as plain text. Nothing has been validated at this point.
    TransferRequest = Data.define(:line, :from, :to, :amount)

    # The outcome of one request. `rejection_reason` is nil when the transfer
    # went through, and says why when it did not.
    TransferResult = Data.define(:request, :rejection_reason) do
      def completed?
        rejection_reason.nil?
      end
    end

    # Applies a day's transfers. There are two ways to do it.
    #
    # By default the transfers are applied one at a time, in the order they
    # appear in the file, and each has to be affordable at that moment. A
    # rejected transfer changes no balances and does not stop the transfers
    # after it.
    #
    # With `settle_at_end` the file is treated as one batch. Balances are
    # only checked once, after every transfer in the file has been counted,
    # so a transfer may spend money that arrives later in the file.
    class ProcessTransfers
      NO_MONEY = Domain::Money.new(cents: 0)

      def initialize(accounts:)
        @accounts = accounts
      end

      def call(requests, settle_at_end: false)
        return settle(requests) if settle_at_end

        requests.map { |request| process(request) }
      end

      private

      # Every broken business rule raises a Domain::Error, so the single
      # rescue below turns any of them into a rejection.
      #
      # Both accounts are looked up before any money moves, so a transfer to
      # an account that does not exist takes nothing from the sender.
      def process(request)
        transfer = build_transfer(request)
        source = @accounts.find(transfer.from)
        destination = @accounts.find(transfer.to)
        transfer.apply(source: source, destination: destination)
        TransferResult.new(request: request, rejection_reason: nil)
      rescue Domain::Error => e
        TransferResult.new(request: request, rejection_reason: e.message)
      end

      def build_transfer(request)
        Domain::Transfer.new(
          from: Domain::AccountNumber.new(value: request.from),
          to: Domain::AccountNumber.new(value: request.to),
          amount: Domain::Money.parse(request.amount)
        )
      end

      # A line that cannot be used is rejected by itself, as it is by
      # default. The rest of the file is applied together or not at all: if
      # it would leave any account below $0, every transfer in it is
      # rejected with that reason and no balance changes.
      def settle(requests)
        results = requests.map { |request| check(request) }
        transfers = results.select(&:completed?).map { |result| build_transfer(result.request) }
        refusal = settle_accounts(transfers)
        return results unless refusal

        results.map { |result| result.completed? ? result.with(rejection_reason: refusal) : result }
      end

      # Checks one line without moving any money. The line has to read as a
      # transfer, and both of its accounts have to exist.
      def check(request)
        transfer = build_transfer(request)
        @accounts.find(transfer.from)
        @accounts.find(transfer.to)
        TransferResult.new(request: request, rejection_reason: nil)
      rescue Domain::Error => e
        TransferResult.new(request: request, rejection_reason: e.message)
      end

      # Moves the money for the whole batch and returns nil, or moves none
      # and returns the reason. Every account is checked before any balance
      # changes, so the batch cannot be left half applied.
      #
      # Each account receives everything coming to it before it pays out, so
      # the withdrawal is never refused for an account that passed the check.
      def settle_accounts(transfers)
        accounts = involved_accounts(transfers)
        overdrawn = accounts.select { |account| overdrawn?(account, transfers) }
        return refusal_naming(overdrawn) if overdrawn.any?

        accounts.each do |account|
          account.deposit(received_by(account, transfers))
          account.withdraw(sent_by(account, transfers))
        end
        nil
      end

      def involved_accounts(transfers)
        numbers = transfers.flat_map { |transfer| [transfer.from, transfer.to] }.uniq
        numbers.map { |number| @accounts.find(number) }
      end

      def overdrawn?(account, transfers)
        account.overdrawn_after?(
          incoming: received_by(account, transfers),
          outgoing: sent_by(account, transfers)
        )
      end

      def received_by(account, transfers)
        transfers.select { |transfer| transfer.to == account.number }.sum(NO_MONEY, &:amount)
      end

      def sent_by(account, transfers)
        transfers.select { |transfer| transfer.from == account.number }.sum(NO_MONEY, &:amount)
      end

      def refusal_naming(accounts)
        numbers = accounts.map(&:number).join(', ')
        "nothing in this file was applied, because it would leave #{numbers} below $0"
      end
    end
  end
end
