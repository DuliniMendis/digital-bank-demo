# frozen_string_literal: true

RSpec.describe Bank::Domain::Money do
  def money(cents)
    described_class.new(cents: cents)
  end

  describe '.parse' do
    it 'reads dollars and cents' do
      expect(described_class.parse('25.60')).to eq(money(2560))
    end

    it 'reads whole dollars' do
      expect(described_class.parse('500')).to eq(money(50_000))
    end

    it 'reads one decimal digit as tens of cents' do
      expect(described_class.parse('0.5')).to eq(money(50))
    end

    it 'ignores spaces around the amount' do
      expect(described_class.parse(' 12.00 ')).to eq(money(1200))
    end

    ['-5.00', 'abc', '1.234', '1,000.00'].each do |bad_text|
      it "rejects #{bad_text.inspect}" do
        expect { described_class.parse(bad_text) }
          .to raise_error(Bank::Domain::InvalidMoney, /is not a valid amount/)
      end
    end

    it 'says so when the amount is missing' do
      expect { described_class.parse(nil) }
        .to raise_error(Bank::Domain::InvalidMoney, 'amount is missing')
    end
  end

  describe '.new' do
    it 'rejects a negative number of cents' do
      expect { money(-1) }.to raise_error(Bank::Domain::InvalidMoney)
    end

    it 'rejects a number of cents that is not whole' do
      expect { money(10.5) }.to raise_error(Bank::Domain::InvalidMoney)
    end
  end

  describe '#+' do
    it 'adds two amounts' do
      expect(money(150) + money(275)).to eq(money(425))
    end
  end

  describe '#-' do
    it 'subtracts one amount from another' do
      expect(money(500) - money(125)).to eq(money(375))
    end

    it 'refuses to go below zero' do
      expect { money(100) - money(101) }.to raise_error(Bank::Domain::InvalidMoney)
    end
  end

  describe '#>' do
    it 'is true for the larger amount' do
      expect(money(200) > money(100)).to be(true)
    end

    it 'is false when the amounts are equal' do
      same_amount = money(100)

      expect(money(100) > same_amount).to be(false)
    end
  end

  describe '#zero?' do
    it 'is true for zero cents' do
      expect(money(0)).to be_zero
    end

    it 'is false for any other amount' do
      expect(money(1)).not_to be_zero
    end
  end

  describe '#to_s' do
    it 'shows dollars and two-digit cents' do
      expect(money(123_450).to_s).to eq('1234.50')
    end

    it 'pads cents below ten with a zero' do
      expect(money(5).to_s).to eq('0.05')
    end
  end
end
