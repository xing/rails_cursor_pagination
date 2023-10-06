# frozen_string_literal: true

module RailsCursorPagination
  # Cursor class that's used to uniquely identify a record and serialize and
  # deserialize this cursor so that it can be used for pagination.
  # This class expects the `order_field` of the record to be a timestamp and is
  # to be used only when sorting a
  class TimestampCursor < Cursor
    class << self
      # Decode the provided encoded cursor. Returns an instance of this
      # `RailsCursorPagination::Cursor` class containing both the ID and the
      # ordering field value. The ordering field is expected to be a timestamp
      # and is always decoded in the UTC timezone.
      #
      # @param encoded_string [String]
      #   The encoded cursor
      # @param order_field [Symbol]
      #   The column that is being ordered on. It needs to be a timestamp of a
      #   class that responds to `#strftime`.
      # @raise [RailsCursorPagination::InvalidCursorError]
      #   In case the given `encoded_string` cannot be decoded properly
      # @return [RailsCursorPagination::TimestampCursor]
      #   Instance of this class with a properly decoded timestamp cursor
      def decode(encoded_string:, order_field:)
        decoded = JSON.parse(Base64.strict_decode64(encoded_string))

        new(
          id: decoded[1],
          order_field: order_field,
          # Turn the order field value into a `Time` instance in UTC. A Rational
          # number allows us to represent fractions of seconds, including the
          # microseconds. In this way we can preserve the order of items with a
          # microsecond precision.
          # This also allows us to keep the size of the cursor small by using
          # just a number instead of having to pass seconds and the fraction of
          # seconds separately.
          order_field_value: Time.at(decoded[0].to_r / (10**6)).utc
        )
      rescue ArgumentError, JSON::ParserError
        raise InvalidCursorError,
              "The given cursor `#{encoded_string}` " \
              'could not be decoded to a timestamp'
      end
    end

    # Initializes the record. Overrides `Cursor`'s initializer making all params
    # mandatory.
    #
    # @param id [Integer]
    #   The ID of the cursor record
    # @param order_field [Symbol]
    #   The column or virtual column for ordering
    # @param order_field_value [Object]
    #   The value that the +order_field+ of the record contains
    def initialize(id:, order_field:, order_field_value:)
      super id: id,
            order_field: order_field,
            order_field_value: order_field_value
    end

    # Encodes the cursor as an array containing the timestamp as microseconds
    # from UNIX epoch and the id of the object
    #
    # @raise [RailsCursorPagination::ParameterError]
    #   The order field value needs to respond to `#strftime` to use the
    #   `TimestampCursor` class. Otherwise, a `ParameterError` is raised.
    # @return [String]
    def encode
      unless @order_field_value.respond_to?(:strftime)
        raise ParameterError,
              "Could not encode #{@order_field} " \
              "with value #{@order_field_value}." \
              'It does not respond to #strftime. Is it a timestamp?'
      end

      Base64.strict_encode64(
        [
          @order_field_value.strftime('%s%6N').to_i,
          @id
        ].to_json
      )
    end
  end
end
