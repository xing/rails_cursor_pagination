# frozen_string_literal: true

RSpec.describe RailsCursorPagination::VERSION do
  it { is_expected.not_to be nil }
  it { is_expected.to be_a String }

  it 'uses gem-flavored semantic versioning' do
    is_expected.to match(/^\d+.\d+.\d+(.[\w\d]+)$/)
  end
end
