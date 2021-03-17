# frozen_string_literal: true

RSpec.describe RailsCursorPagination::VERSION do
  subject(:version_number) { RailsCursorPagination::VERSION }

  it { is_expected.not_to be nil }
  it { is_expected.to be_a String }

  it 'uses gem-flavored semantic versioning' do
    is_expected.to match(/^\d+.\d+.\d+(.[\w\d]+)?$/)
  end

  describe 'CHANGELOG.md' do
    let(:changelog_file_path) { "#{File.dirname(__FILE__)}/../../CHANGELOG.md" }
    subject { File.read(changelog_file_path) }

    it 'includes a section for the current version' do
      is_expected.to match(/^## \[#{version_number}\] - 20\d\d-\d\d-\d\d$/)
    end
  end
end
