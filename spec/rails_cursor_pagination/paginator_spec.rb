# frozen_string_literal: true

RSpec.describe RailsCursorPagination::Paginator do
  subject(:instance) { described_class.new(relation, **params) }

  let(:relation) { Post.all }
  let(:params) { {} }

  describe '.new' do
    context 'when passing valid parameters' do
      shared_examples 'for a working combination with `order` param' do
        context 'and custom order' do
          context 'set to ascending' do
            let(:params) { super().merge(order: :asc) }

            it { is_expected.to be_a described_class }
          end

          context 'set to descending' do
            let(:params) { super().merge(order: :desc) }

            it { is_expected.to be_a described_class }
          end
        end
      end

      shared_examples 'for a working combination with `order_by` param' do
        context 'and custom order_by' do
          let(:params) { super().merge(order_by: :author) }

          it { is_expected.to be_a described_class }

          include_examples 'for a working combination with `order` param'
        end
      end

      shared_examples 'for a working parameter combination' do
        it { is_expected.to be_a described_class }

        include_examples 'for a working combination with `order` param'
        include_examples 'for a working combination with `order_by` param'
      end

      context 'when only passing the relation' do
        include_examples 'for a working parameter combination'
      end

      context 'when passing only first' do
        let(:params) { { first: 2 } }

        include_examples 'for a working parameter combination'
      end

      context 'when passing first and after' do
        let(:params) { { first: 2, after: 'abc' } }

        include_examples 'for a working parameter combination'
      end

      context 'when passing last and before' do
        let(:params) { { last: 2, before: 'xyz' } }

        include_examples 'for a working parameter combination'
      end
    end

    context 'when passing invalid parameters' do
      shared_examples 'for a ParameterError with the right message' do |message|
        it 'raises an error with the right message' do
          expect { subject }
            .to raise_error ::RailsCursorPagination::Paginator::ParameterError,
                            message
        end
      end

      context 'not passing an ActiveRecord::Relation as first argument' do
        let(:relation) { :tasty_cookies }

        include_examples 'for a ParameterError with the right message',
                         'The first argument must be an '\
                         'ActiveRecord::Relation, but was the Symbol '\
                         '`:tasty_cookies`'
      end

      context 'passing an invalid `order`' do
        let(:params) { super().merge(order: :happiness) }

        include_examples 'for a ParameterError with the right message',
                         '`order` must be either :asc or :desc, but was'\
                         ' `happiness`'
      end

      context 'passing both `first` and `last`' do
        let(:params) { super().merge(first: 2, last: 3) }

        include_examples 'for a ParameterError with the right message',
                         '`first` cannot be combined with `last`'
      end

      context 'passing both `before` and `after`' do
        let(:params) { super().merge(before: 'qwe', after: 'asd') }

        include_examples 'for a ParameterError with the right message',
                         '`before` cannot be combined with `after`'
      end

      context 'passing only `last` without `after`' do
        let(:params) { super().merge(last: 5) }

        include_examples 'for a ParameterError with the right message',
                         '`last` must be combined with `before`'
      end

      context 'passing a negative `first`' do
        let(:params) { super().merge(first: -7) }

        include_examples 'for a ParameterError with the right message',
                         '`first` cannot be negative, but was `-7`'
      end

      context 'passing a negative `last`' do
        let(:params) { super().merge(last: -4, before: 'qwe') }

        include_examples 'for a ParameterError with the right message',
                         '`last` cannot be negative, but was `-4`'
      end
    end
  end

  describe '#fetch' do
    subject(:result) { instance.fetch }

    let(:post_1) { Post.create! id: 1, author: 'John' }
    let(:post_2) { Post.create! id: 2, author: 'Jane' }
    let(:post_3) { Post.create! id: 3, author: 'Jane' }
    let(:post_4) { Post.create! id: 4, author: 'John' }
    let(:post_5) { Post.create! id: 5, author: 'Jane' }
    let(:post_6) { Post.create! id: 6, author: 'John' }
    let(:post_7) { Post.create! id: 7, author: 'Jane' }
    let(:post_8) { Post.create! id: 8, author: 'John' }
    let(:post_9) { Post.create! id: 9, author: 'Jess' }
    let(:post_10) { Post.create! id: 10, author: 'Jess' }
    let(:post_11) { Post.create! id: 11, author: 'John' }
    let(:post_12) { Post.create! id: 12, author: 'John' }
    let(:post_13) { Post.create! id: 13, author: 'Jane' }

    let!(:posts) do
      [
        post_1,
        post_2,
        post_3,
        post_4,
        post_5,
        post_6,
        post_7,
        post_8,
        post_9,
        post_10,
        post_11,
        post_12,
        post_13
      ]
    end
    let(:posts_by_author) do
      # Note that the ID is being used in a string sorting. Therefore, the order
      # is '1' < '10' < '2' (instead of 1 < 2 < 10 as it would be for integers).
      [
        # All posts by "Jane"
        post_13,
        post_2,
        post_3,
        post_5,
        post_7,
        post_10,
        # All posts by "Jess"
        post_9,
        post_1,
        # All posts by "John"
        post_11,
        post_12,
        post_4,
        post_6,
        post_8
      ]
    end

    let(:cursor_object) { nil }
    let(:cursor_object_plain) { nil }
    let(:cursor_object_desc) { nil }
    let(:cursor_object_by_author) { nil }
    let(:cursor_object_by_author_desc) { nil }
    let(:query_cursor_base) { cursor_object&.id }
    let(:query_cursor) { Base64.strict_encode64(query_cursor_base.to_json) }

    shared_examples_for 'a properly returned response' do
      let(:expected_start_cursor) do
        Base64.strict_encode64(
          expected_cursor.call(expected_posts.first).to_json
        )
      end
      let(:expected_end_cursor) do
        Base64.strict_encode64(
          expected_cursor.call(expected_posts.last).to_json
        )
      end

      it 'has the correct format' do
        is_expected.to be_a Hash
        is_expected.to have_key :page
        is_expected.to have_key :page_info
      end

      describe 'for :page_info' do
        subject { result[:page_info] }

        it 'includes all relevant meta info' do
          is_expected.to be_a Hash

          expect(subject.keys).to contain_exactly :has_previous_page,
                                                  :has_next_page,
                                                  :start_cursor,
                                                  :end_cursor

          is_expected.to include has_previous_page: expected_has_previous_page,
                                 has_next_page: expected_has_next_page,
                                 start_cursor: expected_start_cursor,
                                 end_cursor: expected_end_cursor
        end
      end

      describe 'for :page' do
        subject { result[:page] }

        let(:returned_parsed_cursors) do
          subject
            .pluck(:cursor)
            .map { |cursor| JSON.parse(Base64.strict_decode64(cursor)) }
        end

        it 'contains the right data' do
          is_expected.to be_an Array
          is_expected.to all be_a Hash
          is_expected.to all include :cursor, :data

          expect(subject.pluck(:data)).to all be_a Post
          expect(subject.pluck(:data)).to match_array expected_posts
          expect(subject.pluck(:data)).to eq expected_posts

          expect(subject.pluck(:cursor)).to all be_a String
          expect(subject.pluck(:cursor)).to all be_present
          expect(returned_parsed_cursors)
            .to eq(expected_posts.map { |post| expected_cursor.call(post) })
        end
      end

      it 'does not return the total by default' do
        is_expected.to be_a Hash
        is_expected.to_not have_key :total
      end

      context 'when passing `with_total: true`' do
        subject(:result) { instance.fetch(with_total: true) }

        it 'also includes the `total` of records' do
          is_expected.to have_key :total
          expect(subject[:total]).to eq expected_total
        end
      end
    end

    shared_examples_for 'a query that works with a descending `order`' do
      let(:params) { super().merge(order: :desc) }

      it_behaves_like 'a properly returned response'
    end

    shared_examples_for 'a query that works with `order_by` param' do
      let(:params) { super().merge(order_by: :author) }

      it_behaves_like 'a properly returned response'

      it_behaves_like 'a query that works with a descending `order`' do
        let(:cursor_object) { cursor_object_desc }

        let(:expected_posts) { expected_posts_desc }
      end
    end

    shared_examples_for 'a query that returns no data when relation is empty' do
      let(:relation) { Post.where(author: 'keks') }

      it_behaves_like 'a properly returned response' do
        let(:expected_posts) { [] }
        let(:expected_has_next_page) { false }
        let(:expected_has_previous_page) { false }
        let(:expected_total) { 0 }
        let(:expected_start_cursor) { nil }
        let(:expected_end_cursor) { nil }
      end
    end

    shared_examples 'for a working query' do
      let(:expected_total) { relation.size }

      it_behaves_like 'a properly returned response' do
        let(:cursor_object) { cursor_object_plain }
        let(:query_cursor_base) { cursor_object&.id }

        let(:expected_posts) { expected_posts_plain }
        let(:expected_cursor) { ->(post) { post.id } }
      end

      it_behaves_like 'a query that works with a descending `order`' do
        let(:cursor_object) { cursor_object_desc }
        let(:query_cursor_base) { cursor_object&.id }

        let(:expected_posts) { expected_posts_desc }
        let(:expected_cursor) { ->(post) { post.id } }
      end

      it_behaves_like 'a query that works with `order_by` param' do
        let(:cursor_object) { cursor_object_by_author }
        let(:cursor_object_desc) { cursor_object_by_author_desc }
        let(:query_cursor_base) { [cursor_object&.author, cursor_object&.id] }

        let(:expected_posts) { expected_posts_by_author }
        let(:expected_posts_desc) { expected_posts_by_author_desc }
        let(:expected_cursor) { ->(post) { [post.author, post.id] } }
      end

      it_behaves_like 'a query that returns no data when relation is empty'
    end

    context 'when neither first/last nor before/after are passed' do
      include_examples 'for a working query' do
        let(:expected_posts_plain) { posts.first(10) }
        let(:expected_posts_desc) { posts.reverse.first(10) }

        let(:expected_posts_by_author) { posts_by_author.first(10) }
        let(:expected_posts_by_author_desc) do
          posts_by_author.reverse.first(10)
        end

        let(:expected_has_next_page) { true }
        let(:expected_has_previous_page) { false }
      end
    end

    context 'when only passing first' do
      let(:params) { { first: 2 } }

      include_examples 'for a working query' do
        let(:expected_posts_plain) { posts.first(2) }
        let(:expected_posts_desc) { posts.reverse.first(2) }

        let(:expected_posts_by_author) { posts_by_author.first(2) }
        let(:expected_posts_by_author_desc) { posts_by_author.reverse.first(2) }

        let(:expected_has_next_page) { true }
        let(:expected_has_previous_page) { false }
      end

      context 'when there are less records than requested' do
        let(:params) { { first: posts.size + 1 } }

        include_examples 'for a working query' do
          let(:expected_posts_plain) { posts }
          let(:expected_posts_desc) { posts.reverse }

          let(:expected_posts_by_author) { posts_by_author }
          let(:expected_posts_by_author_desc) { posts_by_author.reverse }

          let(:expected_has_next_page) { false }
          let(:expected_has_previous_page) { false }
        end
      end
    end

    context 'when passing `after`' do
      let(:params) { { after: query_cursor } }

      include_examples 'for a working query' do
        let(:cursor_object_plain) { posts[0] }
        let(:expected_posts_plain) { posts[1..10] }

        let(:cursor_object_desc) { posts[-1] }
        let(:expected_posts_desc) { posts[-11..-2].reverse }

        let(:cursor_object_by_author) { posts_by_author[0] }
        let(:expected_posts_by_author) { posts_by_author[1..10] }

        let(:cursor_object_by_author_desc) { posts_by_author[-1] }
        let(:expected_posts_by_author_desc) { posts_by_author[-11..-2].reverse }

        let(:expected_has_next_page) { true }
        let(:expected_has_previous_page) { true }
      end

      context 'and `first`' do
        let(:params) { super().merge(first: 2) }

        include_examples 'for a working query' do
          let(:cursor_object_plain) { posts[2] }
          let(:expected_posts_plain) { posts[3..4] }

          let(:cursor_object_desc) { posts[-2] }
          let(:expected_posts_desc) { posts[-4..-3].reverse }

          let(:cursor_object_by_author) { posts_by_author[2] }
          let(:expected_posts_by_author) { posts_by_author[3..4] }

          let(:cursor_object_by_author_desc) { posts_by_author[-2] }
          let(:expected_posts_by_author_desc) do
            posts_by_author[-4..-3].reverse
          end

          let(:expected_has_next_page) { true }
          let(:expected_has_previous_page) { true }
        end

        context 'when not enough records are remaining after cursor' do
          include_examples 'for a working query' do
            let(:cursor_object_plain) { posts[-2] }
            let(:expected_posts_plain) { posts[-1..-1] }

            let(:cursor_object_desc) { posts[1] }
            let(:expected_posts_desc) { posts[0..0].reverse }

            let(:cursor_object_by_author) { posts_by_author[-2] }
            let(:expected_posts_by_author) { posts_by_author[-1..-1] }

            let(:cursor_object_by_author_desc) { posts_by_author[1] }
            let(:expected_posts_by_author_desc) do
              posts_by_author[0..0].reverse
            end

            let(:expected_has_next_page) { false }
            let(:expected_has_previous_page) { true }
          end
        end
      end
    end

    context 'when passing `before`' do
      let(:params) { { before: query_cursor } }

      include_examples 'for a working query' do
        let(:cursor_object_plain) { posts[-1] }
        let(:expected_posts_plain) { posts[-11..-2] }

        let(:cursor_object_desc) { posts[0] }
        let(:expected_posts_desc) { posts[1..10].reverse }

        let(:cursor_object_by_author) { posts_by_author[-1] }
        let(:expected_posts_by_author) { posts_by_author[-11..-2] }

        let(:cursor_object_by_author_desc) { posts_by_author[0] }
        let(:expected_posts_by_author_desc) { posts_by_author[1..10].reverse }

        let(:expected_has_next_page) { true }
        let(:expected_has_previous_page) { true }
      end

      context 'and `last`' do
        let(:params) { super().merge(last: 2) }

        include_examples 'for a working query' do
          let(:cursor_object_plain) { posts[-1] }
          let(:expected_posts_plain) { posts[-3..-2] }

          let(:cursor_object_desc) { posts[2] }
          let(:expected_posts_desc) { posts[3..4].reverse }

          let(:cursor_object_by_author) { posts_by_author[-1] }
          let(:expected_posts_by_author) { posts_by_author[-3..-2] }

          let(:cursor_object_by_author_desc) { posts_by_author[2] }
          let(:expected_posts_by_author_desc) { posts_by_author[3..4].reverse }

          let(:expected_has_next_page) { true }
          let(:expected_has_previous_page) { true }
        end

        context 'when not enough records are remaining before cursor' do
          include_examples 'for a working query' do
            let(:cursor_object_plain) { posts[1] }
            let(:expected_posts_plain) { posts[0..0] }

            let(:cursor_object_desc) { posts[-2] }
            let(:expected_posts_desc) { posts[-1..-1].reverse }

            let(:cursor_object_by_author) { posts_by_author[1] }
            let(:expected_posts_by_author) { posts_by_author[0..0] }

            let(:cursor_object_by_author_desc) { posts_by_author[-2] }
            let(:expected_posts_by_author_desc) do
              posts_by_author[-1..-1].reverse
            end

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { false }
          end
        end
      end
    end
  end
end
