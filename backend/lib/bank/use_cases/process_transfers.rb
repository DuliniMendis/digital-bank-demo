# frozen_string_literal: true

module Bank
  module UseCases
    # One line of the transfers file, exactly as it was read: the line
    # number and the three pieces of text. Nothing has been checked yet.
    TransferRequest = Data.define(:line, :from, :to, :amount)

    # What happened to one TransferRequest. `rejection_reason` is nil when
    # the transfer went through.
    TransferResult = Data.define(:request, :rejection_reason) do
      def completed?
        rejection_reason.nil?
      end
    end

    # ProcessTransfers applies a day's transfers, in file order.
    #
    # Each transfer either completes or is rejected with a reason. A
    # rejected transfer changes no balances and does not stop the ones
    # after it.
    class ProcessTransfers
      def initialize(accounts:)
        @accounts = accounts
      end

      # Returns one TransferResult per request, in the same order.
      def call(requests)
        requests.map { |request| process(request) }
      end

      private

      # Every business rule raises a Domain::Error when it is broken (bad
      # account number, unknown account, insufficient funds and so on), so
      # one rescue turns any of them into a rejection.
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
    end
  end
end
