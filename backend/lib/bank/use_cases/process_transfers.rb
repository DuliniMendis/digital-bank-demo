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

    # A TransferResult read back from the history, with the time its file
    # was uploaded.
    RecordedTransfer = Data.define(:result, :uploaded_at)

    # Raised when a transfers file that was applied before arrives again,
    # and the sender has not confirmed that it should be applied twice.
    class TransfersAlreadyApplied < StandardError; end

    # Applies one uploaded transfers file, in the order of its lines, and
    # records every line in the history. A rejected transfer changes no
    # balances and does not stop the transfers after it.
    #
    # The file has no transfer IDs, and two identical lines in one file can
    # be two real payments, so a repeat cannot be recognised line by line.
    # The whole file is recognised by its fingerprint, a hash of its text. A
    # file seen before is refused unless `apply_again` is true.
    class ProcessTransfers
      def initialize(accounts:, history:)
        @accounts = accounts
        @history = history
      end

      # Checking for an earlier copy, moving the money and recording the
      # results all happen inside one database transaction. If anything
      # fails unexpectedly, none of the file is applied and it can be sent
      # again.
      def call(requests, fingerprint:, apply_again: false)
        @history.one_upload_at_a_time do
          refuse_repeat(fingerprint) unless apply_again
          results = requests.map { |request| process(request) }
          @history.record(fingerprint, results)
          results
        end
      end

      private

      def refuse_repeat(fingerprint)
        return unless @history.uploaded?(fingerprint)

        raise TransfersAlreadyApplied, 'This transfers file has already been applied.'
      end

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
