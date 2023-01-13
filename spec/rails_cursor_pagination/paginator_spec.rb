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
            .to raise_error RailsCursorPagination::ParameterError,
                            message
        end
      end

      context 'not passing an ActiveRecord::Relation as first argument' do
        let(:relation) { :tasty_cookies }

        include_examples 'for a ParameterError with the right message',
                         'The first argument must be an ' \
                         'ActiveRecord::Relation, but was the Symbol ' \
                         '`:tasty_cookies`'
      end

      context 'passing an invalid `order`' do
        let(:params) { super().merge(order: :happiness) }

        include_examples 'for a ParameterError with the right message',
                         '`order` must be either :asc or :desc, but was ' \
                         '`happiness`'
      end

      context 'passing both `first` and `limit`' do
        let(:params) { super().merge(first: 2, limit: 3) }

        include_examples 'for a ParameterError with the right message',
                         '`limit` cannot be combined with `first`'
      end

      context 'passing both `last` and `limit`' do
        let(:params) { super().merge(last: 2, limit: 3) }

        include_examples 'for a ParameterError with the right message',
                         '`limit` cannot be combined with `last`'
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

      context 'passing a negative `limit`' do
        let(:params) { super().merge(limit: -10) }

        include_examples 'for a ParameterError with the right message',
                         '`limit` cannot be negative, but was `-10`'
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

    let(:post_1) { Post.create! id: 1, author: 'John', content: 'Post 1' }
    let(:post_2) { Post.create! id: 2, author: 'Jane', content: 'Post 2' }
    let(:post_3) { Post.create! id: 3, author: 'Jane', content: 'Post 3' }
    let(:post_4) { Post.create! id: 4, author: 'John', content: 'Post 4' }
    let(:post_5) { Post.create! id: 5, author: 'Jane', content: 'Post 5' }
    let(:post_6) { Post.create! id: 6, author: 'John', content: 'Post 6' }
    let(:post_7) { Post.create! id: 7, author: 'Jane', content: 'Post 7' }
    let(:post_8) { Post.create! id: 8, author: 'John', content: 'Post 8' }
    let(:post_9) { Post.create! id: 9, author: 'Jess', content: 'Post 9' }
    let(:post_10) { Post.create! id: 10, author: 'Jess', content: 'Post 10' }
    let(:post_11) { Post.create! id: 11, author: 'John', content: 'Post 11' }
    let(:post_12) { Post.create! id: 12, author: 'John', content: 'Post 12' }
    let(:post_13) { Post.create! id: 13, author: 'Jane', content: 'Post 13' }

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

    shared_examples_for 'a query that works with a descending `order`' do
      let(:params) { super().merge(order: :desc) }

      it_behaves_like 'a well working query that also supports SELECT'
    end

    shared_examples_for 'a query that returns no data when relation is empty' do
      let(:relation) { Post.where(author: 'keks') }

      it_behaves_like 'a well working query that also supports SELECT' do
        let(:expected_posts) { [] }
        let(:expected_has_next_page) { false }
        let(:expected_has_previous_page) { false }
        let(:expected_total) { 0 }
      end
    end

    context 'for basic order_by params' do
      let(:posts_by_order_by_column) do
        # Posts are first ordered by the author's name and then, in case of two
        # posts having the same author, by ID
        [
          # All posts by "Jane"
          post_2,
          post_3,
          post_5,
          post_7,
          post_13,
          # All posts by "Jess"
          post_9,
          post_10,
          # All posts by "John"
          post_1,
          post_4,
          post_6,
          post_8,
          post_11,
          post_12
        ]
      end

      let(:cursor_object) { nil }
      let(:cursor_object_plain) { nil }
      let(:cursor_object_desc) { nil }
      let(:cursor_object_by_order_by_column) { nil }
      let(:cursor_object_by_order_by_column_desc) { nil }
      let(:query_cursor_base) { cursor_object&.id }
      let(:query_cursor) { Base64.strict_encode64(query_cursor_base.to_json) }
      let(:order_by_column) { nil }

      shared_examples_for 'a properly returned response' do
        let(:expected_start_cursor) do
          if expected_posts.any?
            Base64.strict_encode64(
              expected_cursor.call(expected_posts.first).to_json
            )
          end
        end
        let(:expected_end_cursor) do
          if expected_posts.any?
            Base64.strict_encode64(
              expected_cursor.call(expected_posts.last).to_json
            )
          end
        end
        let(:expected_attributes) { %i[id author content updated_at created_at] }

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
            expect(subject.pluck(:data).map(&:attributes).map(&:keys))
              .to all match_array expected_attributes.map(&:to_s)

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

      shared_examples_for 'a well working query that also supports SELECT' do
        context 'when SELECTing all columns' do
          context 'without calling select' do
            it_behaves_like 'a properly returned response'
          end

          context 'including the "*" select' do
            let(:selected_attributes) { ['*'] }

            it_behaves_like 'a properly returned response'
          end
        end

        context 'when SELECTing only some columns' do
          let(:selected_attributes) { %i[id author] }
          let(:relation) { super().select(*selected_attributes) }

          it_behaves_like 'a properly returned response' do
            let(:expected_attributes) { %i[id author] }
          end

          context 'and not including any cursor-relevant column' do
            let(:selected_attributes) { %i[content] }

            it_behaves_like 'a properly returned response' do
              let(:expected_attributes) do
                %i[id content].tap do |attributes|
                  attributes << order_by_column if order_by_column.present?
                end
              end
            end
          end
        end
      end

      shared_examples_for 'a query that works with `order_by` param' do
        let(:params) { super().merge(order_by: order_by_column) }
        let(:order_by_column) { :author }

        it_behaves_like 'a well working query that also supports SELECT'

        it_behaves_like 'a query that works with a descending `order`' do
          let(:cursor_object) { cursor_object_desc }

          let(:expected_posts) { expected_posts_desc }
        end
      end

      shared_examples 'for a working query' do
        let(:expected_total) { relation.size }

        it_behaves_like 'a well working query that also supports SELECT' do
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
          let(:cursor_object) { cursor_object_by_order_by_column }
          let(:cursor_object_desc) { cursor_object_by_order_by_column_desc }
          let(:query_cursor_base) { [cursor_object&.send(order_by_column), cursor_object&.id] }

          let(:expected_posts) { expected_posts_by_order_by_column }
          let(:expected_posts_desc) { expected_posts_by_order_by_column_desc }
          let(:expected_cursor) { ->(post) { [post.send(order_by_column), post.id] } }
        end

        it_behaves_like 'a query that returns no data when relation is empty'
      end

      context 'when neither first/last/limit nor before/after are passed' do
        include_examples 'for a working query' do
          let(:expected_posts_plain) { posts.first(10) }
          let(:expected_posts_desc) { posts.reverse.first(10) }

          let(:expected_posts_by_order_by_column) { posts_by_order_by_column.first(10) }
          let(:expected_posts_by_order_by_column_desc) do
            posts_by_order_by_column.reverse.first(10)
          end

          let(:expected_has_next_page) { true }
          let(:expected_has_previous_page) { false }
        end

        context 'when a different default_page_size has been set' do
          let(:custom_page_size) { 2 }

          before do
            RailsCursorPagination.configure do |config|
              config.default_page_size = custom_page_size
            end
          end

          after { RailsCursorPagination.configure(&:reset!) }

          include_examples 'for a working query' do
            let(:expected_posts_plain) { posts.first(custom_page_size) }
            let(:expected_posts_desc) { posts.reverse.first(custom_page_size) }

            let(:expected_posts_by_order_by_column) do
              posts_by_order_by_column.first(custom_page_size)
            end
            let(:expected_posts_by_order_by_column_desc) do
              posts_by_order_by_column.reverse.first(custom_page_size)
            end

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { false }
          end
        end

        context 'when a max_page_size has been set' do
          let(:max_page_size) { 2 }

          before do
            RailsCursorPagination.configure do |config|
              config.max_page_size = max_page_size
            end
          end

          after { RailsCursorPagination.configure(&:reset!) }

          include_examples 'for a working query' do
            let(:expected_posts_plain) { posts.first(max_page_size) }
            let(:expected_posts_desc) { posts.reverse.first(max_page_size) }

            let(:expected_posts_by_order_by_column) do
              posts_by_order_by_column.first(max_page_size)
            end
            let(:expected_posts_by_order_by_column_desc) do
              posts_by_order_by_column.reverse.first(max_page_size)
            end

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { false }
          end

          context 'when attempting to go over the limit' do
            let(:params) { { first: 5 } }

            include_examples 'for a working query' do
              let(:expected_posts_plain) { posts.first(max_page_size) }
              let(:expected_posts_desc) { posts.reverse.first(max_page_size) }

              let(:expected_posts_by_order_by_column) do
                posts_by_order_by_column.first(max_page_size)
              end
              let(:expected_posts_by_order_by_column_desc) do
                posts_by_order_by_column.reverse.first(max_page_size)
              end

              let(:expected_has_next_page) { true }
              let(:expected_has_previous_page) { false }
            end
          end
        end

        context 'when `order` and `order_by` are explicitly set to `nil`' do
          let(:params) { super().merge(order: nil, order_by: nil) }

          it_behaves_like 'a well working query that also supports SELECT' do
            let(:expected_posts) { posts.first(10) }
            let(:expected_cursor) { ->(post) { post.id } }

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { false }
          end
        end
      end

      context 'when only passing first' do
        let(:params) { { first: 2 } }

        include_examples 'for a working query' do
          let(:expected_posts_plain) { posts.first(2) }
          let(:expected_posts_desc) { posts.reverse.first(2) }

          let(:expected_posts_by_order_by_column) { posts_by_order_by_column.first(2) }
          let(:expected_posts_by_order_by_column_desc) { posts_by_order_by_column.reverse.first(2) }

          let(:expected_has_next_page) { true }
          let(:expected_has_previous_page) { false }
        end

        context 'when there are less records than requested' do
          let(:params) { { first: posts.size + 1 } }

          include_examples 'for a working query' do
            let(:expected_posts_plain) { posts }
            let(:expected_posts_desc) { posts.reverse }

            let(:expected_posts_by_order_by_column) { posts_by_order_by_column }
            let(:expected_posts_by_order_by_column_desc) { posts_by_order_by_column.reverse }

            let(:expected_has_next_page) { false }
            let(:expected_has_previous_page) { false }
          end
        end
      end

      context 'when only passing limit' do
        let(:params) { { limit: 2 } }

        include_examples 'for a working query' do
          let(:expected_posts_plain) { posts.first(2) }
          let(:expected_posts_desc) { posts.reverse.first(2) }

          let(:expected_posts_by_order_by_column) { posts_by_order_by_column.first(2) }
          let(:expected_posts_by_order_by_column_desc) { posts_by_order_by_column.reverse.first(2) }

          let(:expected_has_next_page) { true }
          let(:expected_has_previous_page) { false }
        end

        context 'when there are less records than requested' do
          let(:params) { { first: posts.size + 1 } }

          include_examples 'for a working query' do
            let(:expected_posts_plain) { posts }
            let(:expected_posts_desc) { posts.reverse }

            let(:expected_posts_by_order_by_column) { posts_by_order_by_column }
            let(:expected_posts_by_order_by_column_desc) { posts_by_order_by_column.reverse }

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

          let(:cursor_object_by_order_by_column) { posts_by_order_by_column[0] }
          let(:expected_posts_by_order_by_column) { posts_by_order_by_column[1..10] }

          let(:cursor_object_by_order_by_column_desc) { posts_by_order_by_column[-1] }
          let(:expected_posts_by_order_by_column_desc) { posts_by_order_by_column[-11..-2].reverse }

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

            let(:cursor_object_by_order_by_column) { posts_by_order_by_column[2] }
            let(:expected_posts_by_order_by_column) { posts_by_order_by_column[3..4] }

            let(:cursor_object_by_order_by_column_desc) { posts_by_order_by_column[-2] }
            let(:expected_posts_by_order_by_column_desc) do
              posts_by_order_by_column[-4..-3].reverse
            end

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { true }
          end

          context 'when not enough records are remaining after cursor' do
            include_examples 'for a working query' do
              let(:cursor_object_plain) { posts[-2] }
              let(:expected_posts_plain) { posts[-1..] }

              let(:cursor_object_desc) { posts[1] }
              let(:expected_posts_desc) { posts[0..0].reverse }

              let(:cursor_object_by_order_by_column) { posts_by_order_by_column[-2] }
              let(:expected_posts_by_order_by_column) { posts_by_order_by_column[-1..] }

              let(:cursor_object_by_order_by_column_desc) { posts_by_order_by_column[1] }
              let(:expected_posts_by_order_by_column_desc) do
                posts_by_order_by_column[0..0].reverse
              end

              let(:expected_has_next_page) { false }
              let(:expected_has_previous_page) { true }
            end
          end
        end

        context 'and `limit`' do
          let(:params) { super().merge(limit: 2) }

          include_examples 'for a working query' do
            let(:cursor_object_plain) { posts[2] }
            let(:expected_posts_plain) { posts[3..4] }

            let(:cursor_object_desc) { posts[-2] }
            let(:expected_posts_desc) { posts[-4..-3].reverse }

            let(:cursor_object_by_order_by_column) { posts_by_order_by_column[2] }
            let(:expected_posts_by_order_by_column) { posts_by_order_by_column[3..4] }

            let(:cursor_object_by_order_by_column_desc) { posts_by_order_by_column[-2] }
            let(:expected_posts_by_order_by_column_desc) do
              posts_by_order_by_column[-4..-3].reverse
            end

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { true }
          end

          context 'when not enough records are remaining after cursor' do
            include_examples 'for a working query' do
              let(:cursor_object_plain) { posts[-2] }
              let(:expected_posts_plain) { posts[-1..] }

              let(:cursor_object_desc) { posts[1] }
              let(:expected_posts_desc) { posts[0..0].reverse }

              let(:cursor_object_by_order_by_column) { posts_by_order_by_column[-2] }
              let(:expected_posts_by_order_by_column) { posts_by_order_by_column[-1..] }

              let(:cursor_object_by_order_by_column_desc) { posts_by_order_by_column[1] }
              let(:expected_posts_by_order_by_column_desc) do
                posts_by_order_by_column[0..0].reverse
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

          let(:cursor_object_by_order_by_column) { posts_by_order_by_column[-1] }
          let(:expected_posts_by_order_by_column) { posts_by_order_by_column[-11..-2] }

          let(:cursor_object_by_order_by_column_desc) { posts_by_order_by_column[0] }
          let(:expected_posts_by_order_by_column_desc) { posts_by_order_by_column[1..10].reverse }

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

            let(:cursor_object_by_order_by_column) { posts_by_order_by_column[-1] }
            let(:expected_posts_by_order_by_column) { posts_by_order_by_column[-3..-2] }

            let(:cursor_object_by_order_by_column_desc) { posts_by_order_by_column[2] }
            let(:expected_posts_by_order_by_column_desc) { posts_by_order_by_column[3..4].reverse }

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { true }
          end

          context 'when not enough records are remaining before cursor' do
            include_examples 'for a working query' do
              let(:cursor_object_plain) { posts[1] }
              let(:expected_posts_plain) { posts[0..0] }

              let(:cursor_object_desc) { posts[-2] }
              let(:expected_posts_desc) { posts[-1..].reverse }

              let(:cursor_object_by_order_by_column) { posts_by_order_by_column[1] }
              let(:expected_posts_by_order_by_column) { posts_by_order_by_column[0..0] }

              let(:cursor_object_by_order_by_column_desc) { posts_by_order_by_column[-2] }
              let(:expected_posts_by_order_by_column_desc) do
                posts_by_order_by_column[-1..].reverse
              end

              let(:expected_has_next_page) { true }
              let(:expected_has_previous_page) { false }
            end
          end
        end

        context 'and `limit`' do
          let(:params) { super().merge(limit: 2) }

          include_examples 'for a working query' do
            let(:cursor_object_plain) { posts[-1] }
            let(:expected_posts_plain) { posts[-3..-2] }

            let(:cursor_object_desc) { posts[2] }
            let(:expected_posts_desc) { posts[3..4].reverse }

            let(:cursor_object_by_order_by_column) { posts_by_order_by_column[-1] }
            let(:expected_posts_by_order_by_column) { posts_by_order_by_column[-3..-2] }

            let(:cursor_object_by_order_by_column_desc) { posts_by_order_by_column[2] }
            let(:expected_posts_by_order_by_column_desc) do
              posts_by_order_by_column[3..4].reverse
            end

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { true }
          end

          context 'when not enough records are remaining before cursor' do
            include_examples 'for a working query' do
              let(:cursor_object_plain) { posts[1] }
              let(:expected_posts_plain) { posts[0..0] }

              let(:cursor_object_desc) { posts[-2] }
              let(:expected_posts_desc) { posts[-1..].reverse }

              let(:cursor_object_by_order_by_column) { posts_by_order_by_column[1] }
              let(:expected_posts_by_order_by_column) { posts_by_order_by_column[0..0] }

              let(:cursor_object_by_order_by_column_desc) { posts_by_order_by_column[-2] }
              let(:expected_posts_by_order_by_column_desc) do
                posts_by_order_by_column[-1..].reverse
              end

              let(:expected_has_next_page) { true }
              let(:expected_has_previous_page) { false }
            end
          end
        end
      end
    end

    context 'for timestamped order_by params, i.e. created_at' do
      let(:posts_by_order_by_column) do
        # Posts are first ordered by the created_at
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

      let(:cursor_object) { nil }
      let(:cursor_object_plain) { nil }
      let(:cursor_object_desc) { nil }
      let(:cursor_object_by_order_by_column) { nil }
      let(:cursor_object_by_order_by_column_desc) { nil }
      let(:query_cursor_base) { cursor_object&.id }
      let(:query_cursor) { Base64.strict_encode64(query_cursor_base.to_json) }
      let(:order_by_column) { nil }
      
      shared_examples_for 'a properly returned response' do
        let(:expected_start_cursor) do
          if expected_posts.any?
            Base64.strict_encode64(
              expected_cursor.call(expected_posts.first).to_json
            )
          end
        end
        let(:expected_end_cursor) do
          if expected_posts.any?
            Base64.strict_encode64(
              expected_cursor.call(expected_posts.last).to_json
            )
          end
        end
        let(:expected_attributes) { %i[id author content updated_at created_at] }

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

            expect(subject.pluck(:data).map(&:attributes).map(&:keys))
              .to all match_array expected_attributes.map(&:to_s)
  
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

      shared_examples_for 'a well working query that also supports SELECT' do
        context 'when SELECTing all columns' do
          context 'without calling select' do
            it_behaves_like 'a properly returned response'
          end

          context 'including the "*" select' do
            let(:selected_attributes) { ['*'] }

            it_behaves_like 'a properly returned response'
          end
        end

        context 'when SELECTing only some columns' do
          let(:selected_attributes) { %i[id created_at] }
          let(:relation) { super().select(*selected_attributes) }
  
          it_behaves_like 'a properly returned response' do
            let(:expected_attributes) { %i[id created_at] }
          end
  
          context 'and not including any cursor-relevant column' do
            let(:selected_attributes) { %i[content author] }
  
            it_behaves_like 'a properly returned response' do
              let(:expected_attributes) do
                %i[id content author].tap do |attributes|
                  attributes << order_by_column if order_by_column.present?
                end
              end
            end
          end
        end
      end

      shared_examples_for 'a query that works with timestamped `order_by` param' do
        let(:params) { super().merge(order_by: :created_at) }
        let(:order_by_column) { :created_at }

        it_behaves_like 'a well working query that also supports SELECT'

        it_behaves_like 'a query that works with a descending `order`' do
          let(:cursor_object) { cursor_object_desc }

          let(:expected_posts) { expected_posts_desc }
        end
      end

      shared_examples 'for a working query with timestamped `order_by`' do
        let(:expected_total) { relation.size }

        it_behaves_like 'a well working query that also supports SELECT' do
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

        it_behaves_like 'a query that works with timestamped `order_by` param' do
          let(:cursor_object) { cursor_object_by_order_by_column }
          let(:cursor_object_desc) { cursor_object_by_order_by_column_desc }
          let(:query_cursor_base) { [
            {
              "seconds"=> cursor_object&.created_at&.to_i,
              "nanoseconds"=> cursor_object&.created_at&.nsec
            },
            cursor_object&.id
          ] }
          let(:expected_posts) { expected_posts_by_order_by_column }
          let(:expected_posts_desc) { expected_posts_by_order_by_column_desc }
          let(:expected_cursor) { ->(post) {[
            {
              "seconds"=> post.created_at.to_i,
              "nanoseconds"=> post.created_at.nsec
            },
            post.id
          ]}}
        end

        it_behaves_like 'a query that returns no data when relation is empty'
      end

      context 'when neither first/last/limit nor before/after are passed' do

        include_examples 'for a working query with timestamped `order_by`' do
          let(:expected_posts_plain) { posts.first(10) }
          let(:expected_posts_desc) { posts.reverse.first(10) }

          let(:expected_posts_by_order_by_column) { posts_by_order_by_column.first(10) }
          let(:expected_posts_by_order_by_column_desc) do
            posts_by_order_by_column.reverse.first(10)
          end

          let(:expected_has_next_page) { true }
          let(:expected_has_previous_page) { false }
        end

        context 'when a different default_page_size has been set' do
          let(:custom_page_size) { 2 }

          before do
            RailsCursorPagination.configure do |config|
              config.default_page_size = custom_page_size
            end
          end

          after { RailsCursorPagination.configure(&:reset!) }

          include_examples 'for a working query with timestamped `order_by`' do
            let(:expected_posts_plain) { posts.first(custom_page_size) }
            let(:expected_posts_desc) { posts.reverse.first(custom_page_size) }

            let(:expected_posts_by_order_by_column) do
              posts_by_order_by_column.first(custom_page_size)
            end
            let(:expected_posts_by_order_by_column_desc) do
              posts_by_order_by_column.reverse.first(custom_page_size)
            end

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { false }
          end
        end

        context 'when a max_page_size has been set' do
          let(:max_page_size) { 2 }

          before do
            RailsCursorPagination.configure do |config|
              config.max_page_size = max_page_size
            end
          end

          after { RailsCursorPagination.configure(&:reset!) }

          include_examples 'for a working query with timestamped `order_by`' do
            let(:expected_posts_plain) { posts.first(max_page_size) }
            let(:expected_posts_desc) { posts.reverse.first(max_page_size) }

            let(:expected_posts_by_order_by_column) do
              posts_by_order_by_column.first(max_page_size)
            end
            let(:expected_posts_by_order_by_column_desc) do
              posts_by_order_by_column.reverse.first(max_page_size)
            end

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { false }
          end

          context 'when attempting to go over the limit' do
            let(:params) { { first: 5 } }

            include_examples 'for a working query with timestamped `order_by`' do
              let(:expected_posts_plain) { posts.first(max_page_size) }
              let(:expected_posts_desc) { posts.reverse.first(max_page_size) }

              let(:expected_posts_by_order_by_column) do
                posts_by_order_by_column.first(max_page_size)
              end
              let(:expected_posts_by_order_by_column_desc) do
                posts_by_order_by_column.reverse.first(max_page_size)
              end

              let(:expected_has_next_page) { true }
              let(:expected_has_previous_page) { false }
            end
          end
        end

        context 'when `order` and `order_by` are explicitly set to `nil`' do
          let(:params) { super().merge(order: nil, order_by: nil) }

          it_behaves_like 'a well working query that also supports SELECT' do
            let(:expected_posts) { posts.first(10) }
            let(:expected_cursor) { ->(post) { post.id } }

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { false }
          end
        end
      end

      context 'when only passing first' do
        let(:params) { { first: 2 } }

        include_examples 'for a working query with timestamped `order_by`' do
          let(:expected_posts_plain) { posts.first(2) }
          let(:expected_posts_desc) { posts.reverse.first(2) }

          let(:expected_posts_by_order_by_column) {
            posts_by_order_by_column.first(2)
          }
          let(:expected_posts_by_order_by_column_desc) {
            posts_by_order_by_column.reverse.first(2)
          }

          let(:expected_has_next_page) { true }
          let(:expected_has_previous_page) { false }
        end

        context 'when there are less records than requested' do
          let(:params) { { first: posts.size + 1 } }

          include_examples 'for a working query with timestamped `order_by`' do
            let(:expected_posts_plain) { posts }
            let(:expected_posts_desc) { posts.reverse }

            let(:expected_posts_by_order_by_column) {
              posts_by_order_by_column
            }
            let(:expected_posts_by_order_by_column_desc) {
              posts_by_order_by_column.reverse
            }

            let(:expected_has_next_page) { false }
            let(:expected_has_previous_page) { false }
          end
        end
      end

      context 'when only passing limit' do
        let(:params) { { limit: 2 } }

        include_examples 'for a working query with timestamped `order_by`' do
          let(:expected_posts_plain) { posts.first(2) }
          let(:expected_posts_desc) { posts.reverse.first(2) }

          let(:expected_posts_by_order_by_column) {
            posts_by_order_by_column.first(2)
          }
          let(:expected_posts_by_order_by_column_desc) {
            posts_by_order_by_column.reverse.first(2)
          }

          let(:expected_has_next_page) { true }
          let(:expected_has_previous_page) { false }
        end

        context 'when there are less records than requested' do
          let(:params) { { first: posts.size + 1 } }

          include_examples 'for a working query with timestamped `order_by`' do
            let(:expected_posts_plain) { posts }
            let(:expected_posts_desc) { posts.reverse }

            let(:expected_posts_by_order_by_column) {
              posts_by_order_by_column
            }
            let(:expected_posts_by_order_by_column_desc) {
              posts_by_order_by_column.reverse
            }

            let(:expected_has_next_page) { false }
            let(:expected_has_previous_page) { false }
          end
        end
      end

      context 'when passing `after`' do
        let(:params) { { after: query_cursor } }

        include_examples 'for a working query with timestamped `order_by`' do
          let(:cursor_object_plain) { posts[0] }
          let(:expected_posts_plain) { posts[1..10] }

          let(:cursor_object_desc) { posts[-1] }
          let(:expected_posts_desc) { posts[-11..-2].reverse }

          let(:cursor_object_by_order_by_column) {
            posts_by_order_by_column[0]
          }
          let(:expected_posts_by_order_by_column) {
            posts_by_order_by_column[1..10]
          }

          let(:cursor_object_by_order_by_column_desc) {
            posts_by_order_by_column[-1]
          }
          let(:expected_posts_by_order_by_column_desc) {
            posts_by_order_by_column[-11..-2].reverse
          }

          let(:expected_has_next_page) { true }
          let(:expected_has_previous_page) { true }
        end

        context 'and `first`' do
          let(:params) { super().merge(first: 2) }

          include_examples 'for a working query with timestamped `order_by`' do
            let(:cursor_object_plain) { posts[2] }
            let(:expected_posts_plain) { posts[3..4] }

            let(:cursor_object_desc) { posts[-2] }
            let(:expected_posts_desc) { posts[-4..-3].reverse }

            let(:cursor_object_by_order_by_column) {
              posts_by_order_by_column[2]
            }
            let(:expected_posts_by_order_by_column) {
              posts_by_order_by_column[3..4]
            }
    
            let(:cursor_object_by_order_by_column_desc) {
              posts_by_order_by_column[-2]
            }
            let(:expected_posts_by_order_by_column_desc) do
              posts_by_order_by_column[-4..-3].reverse
            end

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { true }
          end

          context 'when not enough records are remaining after cursor' do
            include_examples 'for a working query with timestamped `order_by`' do
              let(:cursor_object_plain) { posts[-2] }
              let(:expected_posts_plain) { posts[-1..] }

              let(:cursor_object_desc) { posts[1] }
              let(:expected_posts_desc) { posts[0..0].reverse }

              let(:cursor_object_by_order_by_column) {
                posts_by_order_by_column[-2]
              }
              let(:expected_posts_by_order_by_column) {
                posts_by_order_by_column[-1..]
              }

              let(:cursor_object_by_order_by_column_desc) {
                posts_by_order_by_column[1]
              }
              let(:expected_posts_by_order_by_column_desc) do
                posts_by_order_by_column[0..0].reverse
              end

              let(:expected_has_next_page) { false }
              let(:expected_has_previous_page) { true }
            end
          end
        end

        context 'and `limit`' do
          let(:params) { super().merge(limit: 2) }

          include_examples 'for a working query with timestamped `order_by`' do
            let(:cursor_object_plain) { posts[2] }
            let(:expected_posts_plain) { posts[3..4] }

            let(:cursor_object_desc) { posts[-2] }
            let(:expected_posts_desc) { posts[-4..-3].reverse }

            let(:cursor_object_by_order_by_column) {
              posts_by_order_by_column[2]
            }
            let(:expected_posts_by_order_by_column) {
              posts_by_order_by_column[3..4]
            }

            let(:cursor_object_by_order_by_column_desc) {
              posts_by_order_by_column[-2]
            }
            let(:expected_posts_by_order_by_column_desc) do
              posts_by_order_by_column[-4..-3].reverse
            end

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { true }
          end

          context 'when not enough records are remaining after cursor' do
            include_examples 'for a working query with timestamped `order_by`' do
              let(:cursor_object_plain) { posts[-2] }
              let(:expected_posts_plain) { posts[-1..] }

              let(:cursor_object_desc) { posts[1] }
              let(:expected_posts_desc) { posts[0..0].reverse }

              let(:cursor_object_by_order_by_column) {
                posts_by_order_by_column[-2]
              }
              let(:expected_posts_by_order_by_column) {
                posts_by_order_by_column[-1..]
              }

              let(:cursor_object_by_order_by_column_desc) {
                posts_by_order_by_column[1]
              }
              let(:expected_posts_by_order_by_column_desc) do
                posts_by_order_by_column[0..0].reverse
              end

              let(:expected_has_next_page) { false }
              let(:expected_has_previous_page) { true }
            end
          end
        end
      end

      context 'when passing `before`' do
        let(:params) { { before: query_cursor } }
    
        include_examples 'for a working query with timestamped `order_by`' do
          let(:cursor_object_plain) { posts[-1] }
          let(:expected_posts_plain) { posts[-11..-2] }

          let(:cursor_object_desc) { posts[0] }
          let(:expected_posts_desc) {
            posts[1..10].reverse
          }

          let(:cursor_object_by_order_by_column) {
            posts_by_order_by_column[-1]
          }
          let(:expected_posts_by_order_by_column) {
            posts_by_order_by_column[-11..-2]
          }

          let(:cursor_object_by_order_by_column_desc) {
            posts_by_order_by_column[0]
          }
          let(:expected_posts_by_order_by_column_desc) {
            posts_by_order_by_column[1..10].reverse
          }

          let(:expected_has_next_page) { true }
          let(:expected_has_previous_page) { true }
        end

        context 'and `last`' do
          let(:params) { super().merge(last: 2) }

          include_examples 'for a working query with timestamped `order_by`' do
            let(:cursor_object_plain) { posts[-1] }
            let(:expected_posts_plain) { posts[-3..-2] }

            let(:cursor_object_desc) { posts[2] }
            let(:expected_posts_desc) { posts[3..4].reverse }

            let(:cursor_object_by_order_by_column) {
              posts_by_order_by_column[-1]
            }
            let(:expected_posts_by_order_by_column) {
              posts_by_order_by_column[-3..-2]
            }

            let(:cursor_object_by_order_by_column_desc) {
              posts_by_order_by_column[2]
            }
            let(:expected_posts_by_order_by_column_desc) {
              posts_by_order_by_column[3..4].reverse
            }

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { true }
          end

          context 'when not enough records are remaining before cursor' do
            include_examples 'for a working query with timestamped `order_by`' do
              let(:cursor_object_plain) { posts[1] }
              let(:expected_posts_plain) { posts[0..0] }

              let(:cursor_object_desc) { posts[-2] }
              let(:expected_posts_desc) { posts[-1..].reverse }

              let(:cursor_object_by_order_by_column) {
                posts_by_order_by_column[1]
              }
              let(:expected_posts_by_order_by_column) {
                posts_by_order_by_column[0..0]
              }

              let(:cursor_object_by_order_by_column_desc) {
                posts_by_order_by_column[-2]
              }
              let(:expected_posts_by_order_by_column_desc) do
                posts_by_order_by_column[-1..].reverse
              end

              let(:expected_has_next_page) { true }
              let(:expected_has_previous_page) { false }
            end
          end
        end

        context 'and `limit`' do
          let(:params) { super().merge(limit: 2) }

          include_examples 'for a working query with timestamped `order_by`' do
            let(:cursor_object_plain) { posts[-1] }
            let(:expected_posts_plain) { posts[-3..-2] }

            let(:cursor_object_desc) { posts[2] }
            let(:expected_posts_desc) { posts[3..4].reverse }

            let(:cursor_object_by_order_by_column) {
              posts_by_order_by_column[-1]
            }
            let(:expected_posts_by_order_by_column) {
              posts_by_order_by_column[-3..-2]
            }

            let(:cursor_object_by_order_by_column_desc) {
              posts_by_order_by_column[2]
            }
            let(:expected_posts_by_order_by_column_desc) do
              posts_by_order_by_column[3..4].reverse
            end

            let(:expected_has_next_page) { true }
            let(:expected_has_previous_page) { true }
          end

          context 'when not enough records are remaining before cursor' do
            include_examples 'for a working query with timestamped `order_by`' do
              let(:cursor_object_plain) { posts[1] }
              let(:expected_posts_plain) { posts[0..0] }
              let(:cursor_object_desc) { posts[-2] }
              let(:expected_posts_desc) { posts[-1..].reverse }
              let(:cursor_object_by_order_by_column) {
                posts_by_order_by_column[1]
              }
              let(:expected_posts_by_order_by_column) {
                posts_by_order_by_column[0..0]
              }
              let(:cursor_object_by_order_by_column_desc) {
                posts_by_order_by_column[-2]
              }
              let(:expected_posts_by_order_by_column_desc) do
                posts_by_order_by_column[-1..].reverse
              end
              let(:expected_has_next_page) { true }
              let(:expected_has_previous_page) { false }
            end
          end
        end
      end
    end
  end
end
