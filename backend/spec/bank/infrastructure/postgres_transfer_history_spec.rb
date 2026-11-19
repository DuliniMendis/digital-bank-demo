# frozen_string_literal: true

RSpec.describe Bank::Infrastructure::PostgresTransferHistory do
  subject(:history) { described_class.new(database) }

  def result(line, amount, rejection_reason: nil)
    request = Bank::UseCases::TransferRequest.new(
      line: line, from: '1111234522226789', to: '1212343433335665', amount: amount
    )
    Bank::UseCases::TransferResult.new(request: request, rejection_reason: rejection_reason)
  end

  context 'with one connection', :database do
    it 'returns what was recorded, including the reason for a rejection' do
      rejected = result(1, 'abc', rejection_reason: '"abc" is not a valid amount')
      history.record('a' * 64, [rejected])

      expect(history.all.first.result).to eq(rejected)
    end

    it 'lists the newest file first, and each file in line order' do
      history.record('a' * 64, [result(1, '1.00'), result(2, '2.00')])
      history.record('b' * 64, [result(1, '3.00')])

      expect(history.all.map { |recorded| recorded.result.request.amount }).to eq(%w[3.00 1.00 2.00])
    end

    it 'knows which files have been uploaded' do
      history.record('a' * 64, [result(1, '1.00')])

      expect([history.uploaded?('a' * 64), history.uploaded?('b' * 64)]).to eq([true, false])
    end

    it 'forgets everything when cleared' do
      history.record('a' * 64, [result(1, '1.00')])
      history.clear

      expect(history.all).to be_empty
    end
  end

  # A lock can only be seen at work between two database connections, so
  # this example is not tagged :database, which would keep it on one. Each
  # thread below gets a connection of its own. Nothing is written to the
  # table, so there is nothing to tidy up.
  context 'with two uploads arriving at the same time' do
    let(:database) { DatabaseHelper.database }
    let(:events) { Queue.new }

    def slow_upload
      history.one_upload_at_a_time do
        events << :started
        sleep 0.05
        events << :finished
      end
    end

    it 'makes the second wait until the first has finished' do
      Array.new(2) { Thread.new { slow_upload } }.each(&:join)

      expect(Array.new(4) { events.pop }).to eq(%i[started finished started finished])
    end
  end
end
