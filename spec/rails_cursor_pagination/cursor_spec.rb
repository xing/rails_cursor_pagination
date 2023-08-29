# frozen_string_literal: true

RSpec.describe RailsCursorPagination::Cursor do
  describe '#encode' do
    let(:record) { Post.create! id: 1, author: 'John', content: 'Post 1' }

    context 'when ordering by id implicitly' do
      subject(:encoded) do
        described_class.from_record(record: record).encode
      end

      it 'produces a valid string' do
        expect(encoded).to be_a(String)
      end

      it 'can be decoded back to the originally encoded value' do
        decoded = described_class.decode(encoded_string: encoded)
        expect(decoded.id).to eq record.id
      end
    end

    context 'when ordering by id explicitly' do
      subject(:encoded) do
        described_class.from_record(record: record, order_field: :id).encode
      end

      it 'produces a valid string' do
        expect(encoded).to be_a(String)
      end

      it 'can be decoded back to the originally encoded value' do
        decoded = described_class.decode(encoded_string: encoded,
                                         order_field: :id)
        expect(decoded.id).to eq record.id
      end
    end

    context 'when ordering by author' do
      subject(:encoded) do
        described_class.from_record(record: record, order_field: :author).encode
      end

      it 'produces a valid string' do
        expect(encoded).to be_a(String)
      end

      it 'can be decoded back to the originally encoded value' do
        decoded = described_class.decode(encoded_string: encoded,
                                         order_field: :author)
        expect(decoded.id).to eq record.id
        expect(decoded.order_field_value).to eq record.author
      end
    end

    context 'when specifying a custom primary key' do
      subject(:encoded) do
        described_class.from_record(record: record, primary_key: :author).encode
      end

      it 'produces a valid string' do
        expect(encoded).to be_a(String)
      end

      it 'can be decoded back to the originally encoded value' do
        decoded = described_class.decode(encoded_string: encoded,
                                         primary_key: :author)
        expect(decoded.primary_key_value).to eq record.author
      end
    end
  end

  describe '#id' do
    let(:record) { Post.create! id: 1, author: 'John', content: 'Post 1' }

    context 'when the primary_key is :id (default)' do
      subject(:cursor) { described_class.from_record(record: record) }

      it 'returns the id of the record' do
        expect(cursor.id).to eq(record.id)
      end
    end

    context 'when the primary_key is not :id' do
      subject(:cursor) do
        described_class.from_record(record: record, primary_key: :author)
      end

      it 'raises an error' do
        expect { cursor.id }.to(
          raise_error(
            RailsCursorPagination::ParameterError,
            'When using custom primary keys, the #id method is not supported'
          )
        )
      end
    end
  end

  describe '.from_record' do
    let(:record) { Post.create! id: 1, author: 'John', content: 'Post 1' }

    context 'when not specifying the order_field and primary_key' do
      subject(:from_record) { described_class.from_record(record: record) }

      it 'returns a cursor with the same ID as the record' do
        expect(from_record).to be_a(RailsCursorPagination::Cursor)
        expect(from_record.id).to eq record.id
      end
    end

    context 'when specifying the order_field' do
      subject(:from_record) do
        described_class.from_record(record: record, order_field: :author)
      end

      it 'returns a cursor with the same ID as the record' do
        expect(from_record).to be_a(RailsCursorPagination::Cursor)
        expect(from_record.id).to eq record.id
      end

      it 'returns a cursor with the order_field_value as the record' do
        expect(from_record.order_field_value).to eq record.author
      end
    end

    context 'when specifying the primary_key' do
      subject(:from_record) do
        described_class.from_record(record: record, primary_key: :author)
      end

      it 'returns a cursor with the specified primary key value' do
        expect(from_record).to be_a(RailsCursorPagination::Cursor)
        expect(from_record.primary_key_value).to eq record.author
      end
    end
  end

  describe '.decode' do
    context 'when decoding an encoded message with order_field :id' do
      let(:record) { Post.create! id: 1, author: 'John', content: 'Post 1' }
      let(:encoded) { described_class.from_record(record: record).encode }

      context 'and the order_field to decode is set to :id (implicitly)' do
        subject(:decoded) do
          described_class.decode(encoded_string: encoded)
        end

        it 'decodes the string succesfully' do
          expect(decoded.id).to eq record.id
        end
      end

      context 'and the order_field to decode is set to :id (explicitly)' do
        subject(:decoded) do
          described_class.decode(encoded_string: encoded, order_field: :id)
        end

        it 'decodes the string succesfully' do
          expect(decoded.id).to eq record.id
        end
      end

      context 'and the order_field to decode is set to :author' do
        subject(:decoded) do
          described_class.decode(encoded_string: encoded, order_field: :author)
        end

        it 'raises an InvalidCursorError' do
          message = "The given cursor `#{encoded}` was decoded as " \
                    "`#{record.id}` but could not be parsed"
          expect { decoded }.to raise_error(
            RailsCursorPagination::InvalidCursorError,
            message
          )
        end
      end
    end

    context 'when decoding an encoded message with order_field :author' do
      let(:record) { Post.create! id: 1, author: 'John', content: 'Post 1' }
      let(:encoded) do
        described_class.from_record(record: record, order_field: :author).encode
      end

      context 'and the order_field to decode is set to :id' do
        subject(:decoded) do
          described_class.decode(encoded_string: encoded)
        end

        it 'raises an InvalidCursorError' do
          message = "The given cursor `#{encoded}` was decoded as " \
                    "`[\"#{record.author}\", #{record.id}]` " \
                    'but could not be parsed'
          expect { decoded }.to raise_error(
            RailsCursorPagination::InvalidCursorError,
            message
          )
        end
      end

      context 'and the order_field to decode is set to :author' do
        subject(:decoded) do
          described_class.decode(encoded_string: encoded, order_field: :author)
        end

        it 'decodes the string succesfully' do
          expect(decoded.id).to eq record.id
          expect(decoded.order_field_value).to eq record.author
        end
      end
    end

    context 'when decoding a message that did not come from a known encoder' do
      let(:encoded) { 'SomeGarbageString' }

      context 'and the order_field to decode is set to :id' do
        subject(:decoded) do
          described_class.decode(encoded_string: encoded)
        end

        it 'raises an InvalidCursorError' do
          message = "The given cursor `#{encoded}` " \
                    'could not be decoded'
          expect { decoded }.to raise_error(
            RailsCursorPagination::InvalidCursorError,
            message
          )
        end
      end

      context 'and the order_field to decode is set to :author' do
        subject(:decoded) do
          described_class.decode(encoded_string: encoded, order_field: :author)
        end

        it 'raises an InvalidCursorError' do
          message = "The given cursor `#{encoded}` " \
                    'could not be decoded'
          expect { decoded }.to raise_error(
            RailsCursorPagination::InvalidCursorError,
            message
          )
        end
      end
    end

    context 'when decoding a message with a custom primary key' do
      let(:record) { Post.create! id: 1, author: 'John', content: 'Post 1' }
      let(:encoded) do
        described_class
          .from_record(
            record: record,
            order_field: :author,
            primary_key: :author
          ).encode
      end
      subject(:decoded) do
        described_class.decode(encoded_string: encoded)
      end

      it 'decodes the string successfully' do
        expect(decoded.primary_key_value).to eq(record.author)
      end
    end
  end

  describe '.new' do
    subject(:cursor) { described_class.new(**initializer_params) }

    context 'when initialized with a primary key value' do
      context 'and only a primary key value' do
        let(:initializer_params) { { primary_key_value: 13 } }

        it 'returns an instance of a Cursor' do
          expect(cursor).to be_a(RailsCursorPagination::Cursor)
        end
      end

      context 'and a primary_key' do
        let(:initializer_params) do
          { primary_key_value: 'John', primary_key: :author }
        end

        context 'but no matching order_field' do
          it 'returns an instance of a Cursor' do
            expect(cursor).to be_a(RailsCursorPagination::Cursor)
          end

          it 'sets the order field with the primary key' do
            expect(cursor.instance_variable_get(:@order_field)).to eq(:author)
          end
        end

        context 'and a matching order_field' do
          let(:initializer_params) { super().merge(order_field: :author) }

          it 'returns an instance of a Cursor' do
            expect(cursor).to be_a(RailsCursorPagination::Cursor)
          end
        end
      end

      context 'and an order_field' do
        context 'but no order_field_value' do
          let(:initializer_params) do
            { primary_key_value: 13, order_field: :author }
          end

          it 'raises a ParameterError' do
            message = 'The `order_field` was set to ' \
                      '`:author` but no `order_field_value` was set'
            expect { cursor }.to raise_error(
              RailsCursorPagination::ParameterError,
              message
            )
          end
        end

        context 'and an order_field_value' do
          let(:initializer_params) do
            {
              primary_key_value: 13,
              order_field: :author,
              order_field_value: 'Thomas'
            }
          end

          it 'returns an instance of a Cursor' do
            expect(cursor).to be_a(RailsCursorPagination::Cursor)
          end
        end
      end
    end
  end
end
