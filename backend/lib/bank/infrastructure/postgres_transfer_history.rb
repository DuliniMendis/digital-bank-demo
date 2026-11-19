# frozen_string_literal: true

module Bank
  module Infrastructure
    # Keeps a record of every uploaded transfers file in the `transfers`
    # table: one row per line of the file, with what happened to it.
    class PostgresTransferHistory
      def initialize(database)
        @database = database
        @table = database[:transfers]
      end

      # Runs the block in a transaction that holds a lock on the whole table,
      # so a second upload waits here until the first has finished. Without
      # it, two copies of the same file arriving together could both find
      # that the file is new, and both be applied. The history can still be
      # read while the lock is held.
      def one_upload_at_a_time
        @database.transaction do
          @table.lock('EXCLUSIVE')
          yield
        end
      end

      def uploaded?(fingerprint)
        !@table.where(fingerprint: fingerprint).empty?
      end

      # Stores one row for each result. They all get the same upload time,
      # which is what groups them as one file in the history.
      def record(fingerprint, results)
        uploaded_at = Time.now
        results.each do |result|
          @table.insert(to_row(result).merge(fingerprint: fingerprint, uploaded_at: uploaded_at))
        end
      end

      # The most recent upload comes first. Within one upload the lines are
      # in file order.
      def all
        @table.order(Sequel.desc(:uploaded_at), :line).map { |row| to_recorded_transfer(row) }
      end

      def clear
        @table.delete
      end

      private

      def to_row(result)
        request = result.request
        {
          line: request.line, from_account: request.from, to_account: request.to,
          amount: request.amount, rejection_reason: result.rejection_reason
        }
      end

      def to_recorded_transfer(row)
        request = UseCases::TransferRequest.new(
          line: row[:line], from: row[:from_account], to: row[:to_account], amount: row[:amount]
        )
        result = UseCases::TransferResult.new(request: request, rejection_reason: row[:rejection_reason])
        UseCases::RecordedTransfer.new(result: result, uploaded_at: row[:uploaded_at])
      end
    end
  end
end
