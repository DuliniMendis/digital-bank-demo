# frozen_string_literal: true

RSpec.describe Bank::Domain::AccountNumber do
  it 'accepts exactly 16 digits' do
    expect(described_class.new(value: '1111234522226789').to_s).to eq('1111234522226789')
  end

  it 'ignores spaces around the number' do
    expect(described_class.new(value: ' 1111234522226789 ').to_s).to eq('1111234522226789')
  end

  {
    'too short' => '111123452222678',
    'too long' => '11112345222267890',
    'not all digits' => '111123452222678X',
    'missing' => nil
  }.each do |problem, value|
    it "rejects a number that is #{problem}" do
      expect { described_class.new(value: value) }
        .to raise_error(Bank::Domain::InvalidAccountNumber)
    end
  end
end
