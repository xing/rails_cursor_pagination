# frozen_string_literal: true

module RailsCursorPagination
  # Cursor class to provide some wrapped functionality around cursor.
  #
  # When to use:
  # If you want to paginate without using the cursor string and want to use
  # an alternative identifier as cursor (like the ID or a UUID)
  #
  # How to use:
  #
  # cursor = RailsCursorPagination::Cursor.encode(record, :name)
  # page = RailsCursorPagination::Paginator.new(query, after: cursor).fetch
  #
  class Cursor
    attr_accessor :id, :field, :order_field

    # Generate a cursor for the given record and ordering field. The cursor
    # encodes all the data required to then paginate based on it with the given
    # ordering field.
    #
    # @param record [ActiveRecord] Model instance for which we want the cursor
    # @param order_field [Symbol] column or virtual column for the record.
    # @return [String]
    def self.encode(record, order_field)
      new(record.id, order_field, record[order_field]).encode
    end

    # Decodes an encoded cursor
    # Decode the provided cursor. Either just returns the cursor's ID or in case
    # of pagination on any other field, returns a tuple of first the cursor
    # record's other field's field followed by its ID.
    #
    # @param encoded [String] encoded cursor
    # @return [Integer, Array]
    def self.decode(encoded, order_field = :id)
      decoded = JSON.parse(Base64.strict_decode64(encoded))
      unless decoded.is_a?(Array)

        if order_field != :id
          raise InvalidCursorError,
                "The given cursor `#{encoded}` was decoded as "\
                "`#{decoded}` but could not be parsed"
        end

        return new(decoded, :id)
      end

      new(decoded[1], order_field, decoded[0])
    rescue ArgumentError, JSON::ParserError
      raise InvalidCursorError,
            "The given cursor `#{@cursor.inspect}` could not be decoded"
    end

    # Initializes the record
    #
    # @param id [Integer]
    #   The ID of the cursor record
    # @param order_field [Symbol]
    #   The column or virtual column for ordering
    # @param field [Object]
    #   Optional. The value that the +order_field+ of the record contains in
    #   case that the order field is not the ID
    def initialize(id, order_field, field = nil)
      @id = id
      @order_field = order_field
      @field = field
    end

    # Encodes the field and id (or only id)
    # @return [String]
    def encode
      unencoded_cursor =
        if custom_order_field?
          [@field, @id]
        else
          @id
        end
      Base64.strict_encode64(unencoded_cursor.to_json)
    end

    private

    # Returns true when the order has been overridden from the default (ID)
    # @return [Boolean]
    def custom_order_field?
      @order_field != :id
    end
  end
end
