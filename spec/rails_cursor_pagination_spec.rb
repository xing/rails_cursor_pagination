# frozen_string_literal: true

RSpec.describe RailsCursorPagination do
  it { is_expected.to be_a Module }

  describe '.configure' do
    let(:configuration) { RailsCursorPagination::Configuration.instance }
    after { configuration.reset! }

    it 'can be used to configure the gem' do
      expect do
        described_class.configure do |config|
          config.default_page_size = 42
        end
      end.to change { configuration.default_page_size }.to(42)
    end
  end
end
