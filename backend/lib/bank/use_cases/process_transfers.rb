# frozen_string_literal: true

module Bank
  module UseCases
    # A line of the transfers file, not yet validated.
    TransferRequest = Data.define(:line, :from, :to, :amount)

    # What happened to a request. rejection_reason is nil if it went through.
    TransferResult = Data.define(:request, :rejection_reason) do
      def completed?
        rejection_reason.nil?
      end
    end

    # Applies a day's transfers in file order. A rejected transfer changes
    # nothing and does not stop the ones after it.
    class ProcessTransfers
      def initialize(accounts:)
        @accounts = accounts
      end

      def call(requests)
        requests.map { |request| process(request) }
      end

      private

      # Every broken business rule raises a Domain::Error, so this one
      # rescue covers all the reasons a transfer can be rejected. Both
      # accounts are found before any money moves.
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
