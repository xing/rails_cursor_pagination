# frozen_string_literal: true

require 'base64'

module RailsCursorPagination
  # Cursor class that's used to uniquely identify a record and serialize and
  # deserialize this cursor so that it can be used for pagination.
  class Cursor
    attr_reader :primary_key_value, :order_field_value

    class << self
      # Generate a cursor for the given record and ordering field. The cursor
      # encodes all the data required to then paginate based on it with the
      # given ordering field.
      #
      # @param record [ActiveRecord]
      #   Model instance for which we want the cursor
      # @param order_field [Symbol]
      #   Column or virtual column of the record that the relation is ordered by
      # @param primary_key [Symbol, String]
      #   Column or virtual column of the record to be used instead of `id` as
      #   primary key.
      # @return [Cursor]
      def from_record(record:, order_field: :id, primary_key: :id)
        new(primary_key_value: record[primary_key],
            order_field: order_field,
            order_field_value: record[order_field],
            primary_key: primary_key)
      end

      # Decode the provided encoded cursor. Returns an instance of this
      # +RailsCursorPagination::Cursor+ class containing either just the
      # cursor's ID or in case of pagination on any other field, containing
      # both the ID and the ordering field value.
      #
      # @param encoded_string [String]
      #   The encoded cursor
      # @param order_field [Symbol]
      #   Optional. The column that is being ordered on in case it's not the ID
      #   column
      # @return [RailsCursorPagination::Cursor]
      def decode(encoded_string:, order_field: :id, primary_key: :id)
        decoded = JSON.parse(Base64.strict_decode64(encoded_string))
        if order_field == primary_key
          if decoded.is_a?(Array)
            raise InvalidCursorError,
                  "The given cursor `#{encoded_string}` was decoded as " \
                  "`#{decoded}` but could not be parsed"
          end
          new(primary_key_value: decoded,
              order_field: order_field,
              primary_key: primary_key)
        else
          unless decoded.is_a?(Array) && decoded.size == 2
            raise InvalidCursorError,
                  "The given cursor `#{encoded_string}` was decoded as " \
                  "`#{decoded}` but could not be parsed"
          end
          new(primary_key_value: decoded[1], order_field: order_field,
              order_field_value: decoded[0], primary_key: primary_key)
        end
      rescue ArgumentError, JSON::ParserError
        raise InvalidCursorError,
              "The given cursor `#{encoded_string}` could not be decoded"
      end
    end

    # Initializes the record
    #
    # @param primary_key_value [Object]
    #   The identifier of the cursor record
    # @param order_field [Symbol]
    #   The column or virtual column for ordering
    # @param order_field_value [Object]
    #   Optional. The value that the +order_field+ of the record contains in
    #   case that the order field is not the ID
    # @param primary_key [Symbol, String]
    #   Column or virtual column of the record to be used instead of `id` as
    #   primary key
    def initialize(
      primary_key_value:,
      order_field: nil,
      order_field_value: nil,
      primary_key: :id
    )
      @primary_key = primary_key
      @primary_key_value = primary_key_value
      @order_field = order_field || primary_key
      @order_field_value = order_field_value

      return if !custom_order_field? || !order_field_value.nil?

      raise ParameterError, 'The `order_field` was set to ' \
                            "`#{@order_field.inspect}` but " \
                            'no `order_field_value` was set'
    end

    # Generate an encoded string for this cursor. The cursor encodes all the
    # data required to then paginate based on it with the given ordering field.
    #
    # If we only order by primary key, the cursor doesn't need to include any
    # other data.
    # But if we order by any other field, the cursor needs to include both the
    # value from this other field as well as the record's primary key to resolve
    # the order of duplicates in the non-primary-key field.
    #
    # @return [String]
    def encode
      unencoded_cursor =
        if custom_order_field?
          [@order_field_value, @primary_key_value]
        else
          @primary_key_value
        end
      Base64.strict_encode64(unencoded_cursor.to_json)
    end

    # Returns the primary key value if the primary key is `id`. This should
    # cover most cases.
    #
    # @deprecated Use `#primary_key_value` instead
    # @raise [RailsCursorPagination::ParameterError]
    #   Will raise an error if a custom primary key is set.
    # @return [Object]
    def id
      unless @primary_key == :id
        raise RailsCursorPagination::ParameterError,
              'When using custom primary keys, the #id method is not supported'
      end

      primary_key_value
    end

    private

    # Returns true when the order uses a column that is not the primary key.
    #
    # @return [Boolean]
    def custom_order_field?
      @order_field != @primary_key
    end
  end
end
