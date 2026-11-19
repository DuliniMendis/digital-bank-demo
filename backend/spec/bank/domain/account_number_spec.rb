# frozen_string_literal: true

RSpec.describe Bank::Domain::AccountNumber do
  describe '.new' do
    it 'accepts exactly 16 digits' do
      number = described_class.new(value: '1111234522226789')

      expect(number.to_s).to eq('1111234522226789')
    end

    it 'ignores spaces around the number' do
      number = described_class.new(value: ' 1111234522226789 ')

      expect(number.to_s).to eq('1111234522226789')
    end

    {
      'too short' => '111123452222678',
      'too long' => '11112345222267890',
      'contains a letter' => '111123452222678X',
      'empty' => '',
      'missing' => nil
    }.each do |reason, bad_value|
      it "rejects a number that is #{reason}" do
        expect { described_class.new(value: bad_value) }
          .to raise_error(Bank::Domain::InvalidAccountNumber)
      end
    end
  end

  describe 'being a value object' do
    it 'equals another AccountNumber with the same digits' do
      same_digits = described_class.new(value: '1111234522226789')

      expect(described_class.new(value: '1111234522226789')).to eq(same_digits)
    end

    it 'does not equal a different number' do
      expect(described_class.new(value: '1111234522226789'))
        .not_to eq(described_class.new(value: '1111234522221234'))
    end
  end
end
