# frozen_string_literal: true

require 'singleton'

module RailsCursorPagination
  # Cursor for cursor pagination
  class Cursor
    attr_accessor :value, :order_field

    def self.encode(record, order_field)
      new(record.id, order_field, record[order_field]).encode
    end

    def self.decode(encoded, order_field = :id)
      decoded = JSON.parse(Base64.strict_decode64(encoded))
      if !decoded.is_a?(Array) && order_field != :id
        raise InvalidCursorError,
              "The given cursor `#{encoded}` was decoded as "\
              "`#{decoded}` but could not be parsed"
      end
      decoded
    rescue ArgumentError, JSON::ParserError
      raise InvalidCursorError,
            "The given cursor `#{@cursor.inspect}` could not be decoded"
    end

    def initialize(id, order_field, value = nil)
      @id = id
      @order_field = order_field
      @value = value
    end

    def encode
      unencoded_cursor =
        if custom_order_field?
          [@value, @id]
        else
          @id
        end
      Base64.strict_encode64(unencoded_cursor.to_json)
    end

    private

    def custom_order_field?
      @order_field != :id
    end
  end
end