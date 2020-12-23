# frozen_string_literal: true

RSpec.describe RailsCursorPagination::Paginator do
  subject(:instance) { described_class.new(relation) }
  let!(:post_1) { Post.create! id: 1, author: 'Jane' }
  let!(:post_2) { Post.create! id: 2, author: 'John' }
  let!(:post_3) { Post.create! id: 3, author: 'John' }
  let!(:post_4) { Post.create! id: 4, author: 'Jane' }
  let!(:post_5) { Post.create! id: 5, author: 'Jane' }
  let!(:post_6) { Post.create! id: 6, author: 'John' }
  let!(:post_7) { Post.create! id: 7, author: 'John' }

  let(:relation) { Post.all }

  describe '#records' do
    subject { instance.records }

    it 'returns the first 5 records' do
      is_expected.to be_an Array
      expect(subject.size).to eq 5
      expect(subject).to contain_exactly post_1, post_2, post_3, post_4, post_5
    end
  end
end
