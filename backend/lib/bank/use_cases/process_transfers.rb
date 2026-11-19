# frozen_string_literal: true

module Bank
  module UseCases
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

    # Applies a day's transfers in the order they appear in the file. A
    # rejected transfer changes no balances and does not stop the transfers
    # after it. Each transfer runs in its own transaction.
    class ProcessTransfers
      def initialize(accounts:)
        @accounts = accounts
      end

      def call(requests)
        requests.map { |request| process(request) }
      end

      private

      # Every broken business rule raises a Domain::Error, so the single
      # rescue below turns any of them into a rejection.
      def process(request)
        transfer = build_transfer(request)
        @accounts.transaction { move_money(transfer) }
        TransferResult.new(request: request, rejection_reason: nil)
      rescue Domain::Error => e
        TransferResult.new(request: request, rejection_reason: e.message)
      end

      # Both accounts are looked up before any money moves, so a transfer to
      # an account that does not exist takes nothing from the sender. The two
      # saves happen inside the transaction, so both new balances are kept or
      # neither is.
      def move_money(transfer)
        source = @accounts.find(transfer.from)
        destination = @accounts.find(transfer.to)
        transfer.apply(source: source, destination: destination)
        @accounts.save(source)
        @accounts.save(destination)
      end

      def build_transfer(request)
        Domain::Transfer.new(
          from: Domain::AccountNumber.new(value: request.from),
          to: Domain::AccountNumber.new(value: request.to),
          amount: Domain::Money.parse(request.amount)
        )
      end
    end
  end
end
