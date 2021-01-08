# frozen_string_literal: true

RSpec.describe RailsCursorPagination::Configuration do
  # Ensure that all values are back to their defaults after each test
  after { described_class.instance.reset! }

  describe '.instance' do
    it 'returns a singleton instance' do
      expect(described_class.instance).to equal described_class.instance
    end

    it 'sets the default values' do
      expect(described_class.instance.default_page_size).to eq 10
    end
  end

  describe '#reset!' do
    before { described_class.instance.default_page_size = 42 }

    it 'resets the settings to their default' do
      expect { described_class.instance.reset! }
        .to change { described_class.instance.default_page_size }.to(10)
    end
  end
end
