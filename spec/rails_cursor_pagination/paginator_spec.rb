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

  describe '#records' do
    subject { instance.records }

    let(:post_1) { Post.create! id: 1, author: 'Jane' }
    let(:post_2) { Post.create! id: 2, author: 'John' }
    let(:post_3) { Post.create! id: 3, author: 'John' }
    let(:post_4) { Post.create! id: 4, author: 'Jane' }
    let(:post_5) { Post.create! id: 5, author: 'Jane' }
    let(:post_6) { Post.create! id: 6, author: 'John' }
    let(:post_7) { Post.create! id: 7, author: 'John' }

    let!(:posts) { [post_1, post_2, post_3, post_4, post_5, post_6, post_7] }

    it 'returns the first 5 records' do
      is_expected.to be_an Array
      expect(subject.size).to eq described_class::DEFAULT_PAGE_SIZE
      expect(subject).to contain_exactly post_1, post_2, post_3, post_4, post_5
    end
  end
end
