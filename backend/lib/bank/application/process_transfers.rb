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

    # A TransferResult read back from the history, with the time its file
    # was uploaded.
    RecordedTransfer = Data.define(:result, :uploaded_at)

    # Applies one uploaded transfers file, in the order of its lines, and
    # records every line in the history. A rejected transfer changes no
    # balances and does not stop the transfers after it.
    class ProcessTransfers
      def initialize(accounts:, history:)
        @accounts = accounts
        @history = history
      end

      # Moving the money and recording the results happen inside one
      # database transaction. If anything fails unexpectedly, none of the
      # file is applied and it can be sent again.
      def call(requests)
        @history.one_upload_at_a_time do
          results = requests.map { |request| process(request) }
          @history.record(results)
          results
        end
      end

      private

      # Every broken business rule raises a Domain::Error, so the single
      # rescue below turns any of them into a rejection.
      def process(request)
        move_money(build_transfer(request))
        TransferResult.new(request: request, rejection_reason: nil)
      rescue Domain::Error => e
        TransferResult.new(request: request, rejection_reason: e.message)
      end

      # Both accounts are looked up before any money moves, so a transfer to
      # an account that does not exist takes nothing from the sender. A
      # refusal is raised before either account is saved, so a rejected
      # transfer leaves nothing half done.
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
