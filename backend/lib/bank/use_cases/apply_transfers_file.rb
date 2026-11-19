# frozen_string_literal: true

module Bank
  module UseCases
    # A TransferResult read back from the history, with the time its file
    # was uploaded.
    RecordedTransfer = Data.define(:result, :uploaded_at)

    # Raised when a transfers file that was applied before arrives again,
    # and the sender has not confirmed that it should be applied twice.
    class TransfersAlreadyApplied < StandardError; end

    # Applies one uploaded transfers file and records every line of it in
    # the history.
    #
    # The file has no transfer IDs, and two identical lines in one file can
    # be two real payments, so a repeat cannot be recognised line by line.
    # The whole file is recognised by its fingerprint, a hash of its text. A
    # file seen before is refused unless `apply_again` is true.
    class ApplyTransfersFile
      def initialize(accounts:, history:)
        @accounts = accounts
        @history = history
      end

      # Checking for an earlier copy, moving the money and recording the
      # results all happen inside one database transaction. If anything
      # fails unexpectedly, none of the file is applied and it can be sent
      # again.
      def call(fingerprint:, requests:, apply_again: false)
        @history.one_upload_at_a_time do
          refuse_repeat(fingerprint) unless apply_again
          results = ProcessTransfers.new(accounts: @accounts).call(requests)
          @history.record(fingerprint, results)
          results
        end
      end

      private

      def refuse_repeat(fingerprint)
        return unless @history.uploaded?(fingerprint)

        raise TransfersAlreadyApplied, 'This transfers file has already been applied.'
      end
    end
  end
end
