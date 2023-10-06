# frozen_string_literal: true

RSpec.describe RailsCursorPagination::TimestampCursor do
  describe '#encode' do
    let(:record) { Post.create! id: 1, author: 'John', content: 'Post 1' }

    context 'when ordering by a column that is not a timestamp' do
      subject(:encoded) do
        described_class.from_record(record: record, order_field: :author).encode
      end

      it 'raises an error' do
        expect { subject }.to(
          raise_error(
            RailsCursorPagination::ParameterError,
            'Could not encode author ' \
            "with value #{record.author}." \
            'It does not respond to #strftime. Is it a timestamp?'
          )
        )
      end
    end

    context 'when ordering by a timestamp column' do
      subject(:encoded) do
        described_class
          .from_record(record: record, order_field: :created_at)
          .encode
      end

      it 'produces a valid string' do
        expect(encoded).to be_a(String)
      end

      it 'can be decoded back to the originally encoded value' do
        decoded = described_class.decode(encoded_string: encoded,
                                         order_field: :created_at)
        expect(decoded.id).to eq record.id
        expect(decoded.order_field_value).to eq record.created_at
      end
    end
  end

  describe '.decode' do
    context 'when decoding an encoded message with a timestamp order field' do
      let(:record) { Post.create! id: 1, author: 'John', content: 'Post 1' }
      let(:encoded) do
        described_class
          .from_record(record: record, order_field: :created_at)
          .encode
      end

      subject(:decoded) do
        described_class.decode(encoded_string: encoded,
                               order_field: :created_at)
      end

      it 'decodes the string successfully' do
        expect(decoded.id).to eq record.id
        expect(decoded.order_field_value).to eq record.created_at
        expect(decoded.order_field_value.strftime('%s%6N')).to(
          eq record.created_at.strftime('%s%6N')
        )
      end
    end
  end

  describe '.from_record' do
    let(:record) { Post.create! id: 1, author: 'John', content: 'Post 1' }

    subject(:from_record) do
      described_class.from_record(record: record, order_field: :created_at)
    end

    it 'returns a cursor with the same ID as the record' do
      expect(from_record).to be_a(RailsCursorPagination::Cursor)
      expect(from_record.id).to eq record.id
    end

    it 'returns a cursor with the order_field_value as the record' do
      expect(from_record.order_field_value).to eq record.created_at
    end
  end

  describe '.new' do
    subject(:cursor) do
      described_class.new id: 1,
                          order_field: :created_at,
                          order_field_value: Time.now
    end

    it 'returns an instance of a TimestampCursor' do
      expect(cursor).to be_a(RailsCursorPagination::TimestampCursor)
    end
  end
end
