# frozen_string_literal: true

module RailsCursorPagination
  # Use this Paginator class to effortlessly paginate through ActiveRecord
  # relations using cursor pagination. For more details on how this works,
  # read the top-level documentation of the `RailsCursorPagination` module.
  #
  # Usage:
  #     RailsCursorPagination::Paginator
  #       .new(relation, order_by: :author, first: 2, after: "WyJKYW5lIiw0XQ==")
  #       .fetch
  #
  class Paginator
    # Generic error that gets raised when invalid parameters are passed to the
    # Paginator initializer
    class ParameterError < Error; end

    # Error that gets raised if a cursor given as `before` or `after` parameter
    # cannot be properly parsed
    class InvalidCursorError < ParameterError; end

    # Create a new instance of the `RailsCursorPagination::Paginator`
    #
    # @param relation [ActiveRecord::Relation]
    #   Relation that will be paginated.
    # @param first [Integer, nil]
    #   Number of records to return in a forward pagination. Can be combined
    #   with `after`.
    # @param after [String, nil]
    #   Cursor to paginate forward from. Can be combined with `first`.
    # @param last [Integer, nil]
    #   Number of records to return. Must be used together with `before`.
    # @param before [String, nil]
    #   Cursor to paginate upto (excluding). Can be combined with `last`.
    # @param order_by [Symbol, String, nil]
    #   Column to order by. If none is provided, will default to ID column.
    #   NOTE: this will cause an SQL `CONCAT` query. Therefore, you might want
    #   to add an index to your database: `CONCAT(<order_by_field>, '-', id)`
    # @param order [Symbol, nil]
    #   Ordering to apply, either `:asc` or `:desc`. Defaults to `:asc`.
    #
    # @raise [RailsCursorPagination::Paginator::ParameterError]
    #   If any parameter is not valid
    def initialize(relation, first: nil, after: nil, last: nil, before: nil,
                   order_by: nil, order: nil)
      order_by ||= :id
      order ||= :asc

      ensure_valid_params!(relation, first, after, last, before, order)

      @order_field = order_by
      @order_direction = order
      @relation = relation

      @cursor = before || after
      @is_forward_pagination = before.blank?

      @page_size =
        first ||
        last ||
        RailsCursorPagination::Configuration.instance.default_page_size

      @memos = {}
    end

    # Get the paginated result, including the actual `page` with its data items
    # and cursors as well as some meta data in `page_info` and an optional
    # `total` of records across all pages.
    #
    # @param with_total [TrueClass, FalseClass]
    # @return [Hash] with keys :page, :page_info, and optional :total
    def fetch(with_total: false)
      {
        **(with_total ? { total: total } : {}),
        page_info: page_info,
        page: page
      }
    end

    private

    # Ensure that the parameters of this service are valid. Otherwise raise
    # a `RailsCursorPagination::Paginator::ParameterError`.
    #
    # @param relation [ActiveRecord::Relation]
    #   Relation that will be paginated.
    # @param first [Integer, nil]
    #   Optional, must be positive, cannot be combined with `last`
    # @param after [String, nil]
    #   Optional, cannot be combined with `before`
    # @param last [Integer, nil]
    #   Optional, must be positive, requires `before`, cannot be combined
    #   with `first`
    # @param before [String, nil]
    #   Optional, cannot be combined with `after`
    # @param order [Symbol]
    #   Optional, must be :asc or :desc
    #
    # @raise [RailsCursorPagination::Paginator::ParameterError]
    #   If any parameter is not valid
    def ensure_valid_params!(relation, first, after, last, before, order)
      unless relation.is_a?(ActiveRecord::Relation)
        raise ParameterError,
              'The first argument must be an ActiveRecord::Relation, but was '\
              "the #{relation.class} `#{relation.inspect}`"
      end
      unless %i[asc desc].include?(order)
        raise ParameterError,
              "`order` must be either :asc or :desc, but was `#{order}`"
      end
      if first.present? && last.present?
        raise ParameterError, '`first` cannot be combined with `last`'
      end
      if before.present? && after.present?
        raise ParameterError, '`before` cannot be combined with `after`'
      end
      if last.present? && before.blank?
        raise ParameterError, '`last` must be combined with `before`'
      end
      if first.present? && first.negative?
        raise ParameterError, "`first` cannot be negative, but was `#{first}`"
      end
      if last.present? && last.negative?
        raise ParameterError, "`last` cannot be negative, but was `#{last}`"
      end

      true
    end

    # Get meta information about the current page
    #
    # @return [Hash]
    def page_info
      {
        has_previous_page: previous_page?,
        has_next_page: next_page?,
        start_cursor: start_cursor,
        end_cursor: end_cursor
      }
    end

    # Get the records for the given page along with their cursors
    #
    # @return [Array<Hash>] List of hashes, each with a `cursor` and `data`
    def page
      records.map do |item|
        {
          cursor: cursor_for_record(item),
          data: item
        }
      end
    end

    # Get the total number of records in the given relation
    #
    # @return [Integer]
    def total
      memoize(:total) { @relation.size }
    end

    # Check if the pagination direction is forward
    #
    # @return [TrueClass, FalseClass]
    def paginate_forward?
      @is_forward_pagination
    end

    # Check if the user requested to order on a field different than the ID. If
    # a different field was requested, we have to change our pagination logic to
    # accommodate for this.
    #
    # @return [TrueClass, FalseClass]
    def custom_order_field?
      @order_field.downcase.to_sym != :id
    end

    # Check if there is a page before the current one.
    #
    # @return [TrueClass, FalseClass]
    def previous_page?
      if paginate_forward?
        # When paginating forward, we can only have a previous page if we were
        # provided with a cursor and there were records discarded after applying
        # this filter. These records would have to be on previous pages.
        @cursor.present? && filtered_and_sorted_relation.size < total
      else
        # When paginating backwards, if we managed to load one more record than
        # requested, this record will be available on the previous page.
        @page_size < limited_relation_plus_one.size
      end
    end

    # Check if there is another page after the current one.
    #
    # @return [TrueClass, FalseClass]
    def next_page?
      if paginate_forward?
        # When paginating forward, if we managed to load one more record than
        # requested, this record will be available on the next page.
        @page_size < limited_relation_plus_one.size
      else
        # When paginating backward, if applying our cursor reduced the number
        # records returned, we know that the missing records will be on
        # subsequent pages.
        filtered_and_sorted_relation.size < total
      end
    end

    # Load the correct records and return them in the right order
    #
    # @return [Array<ActiveRecord>]
    def records
      records = limited_relation_plus_one.first(@page_size)

      paginate_forward? ? records : records.reverse
    end

    # Apply limit to filtered and sorted relation that contains one item more
    # than the user-requested page size. This is useful for determining if there
    # is an additional page available without having to do a separate DB query.
    #
    # @return [ActiveRecord::Relation]
    def limited_relation_plus_one
      memoize :limited_relation_plus_one do
        filtered_and_sorted_relation.limit(@page_size + 1)
      end
    end

    # Cursor of the first record on the current page
    #
    # @return [String, nil]
    def start_cursor
      return if page.empty?

      page.first[:cursor]
    end

    # Cursor of the last record on the current page
    #
    # @return [String, nil]
    def end_cursor
      return if page.empty?

      page.last[:cursor]
    end

    # Get the order we need to apply to our SQL query. In case we are paginating
    # backwards, this has to be the inverse of what the user requested, since
    # our database can only apply the limit to following records. In the case of
    # backward pagination, we then reverse the order of the loaded records again
    # in `#records` to return them in the right order to the user.
    #
    # Examples:
    #  - first 2 after 4 ascending
    #    -> SELECT * FROM table WHERE id > 4 ODER BY id ASC LIMIT 2
    #  - first 2 after 4 descending                      ^ as requested
    #    -> SELECT * FROM table WHERE id < 4 ODER BY id DESC LIMIT 2
    #  but:                                              ^ as requested
    #  - last 2 before 4 ascending
    #    -> SELECT * FROM table WHERE id < 4 ODER BY id DESC LIMIT 2
    #  - last 2 before 4 descending                      ^ reversed
    #    -> SELECT * FROM table WHERE id > 4 ODER BY id ASC LIMIT 2
    #                                                    ^ reversed
    #
    # @return [Symbol] Either :asc or :desc
    def pagination_sorting
      return @order_direction if paginate_forward?

      @order_direction == :asc ? :desc : :asc
    end

    # Get the right operator to use in the SQL WHERE clause for filtering based
    # on the given cursor. This is dependent on the requested order and
    # pagination direction.
    #
    # If we paginate forward and want ascending records, or if we paginate
    # backward and want descending records we need records that have a higher
    # value than our cursor.
    #
    # On the contrary, if we paginate forward but want descending records, or
    # if we paginate backwards and want ascending records, we need them to have
    # lower values than our cursor.
    #
    # Examples:
    #  - first 2 after 4 ascending
    #    -> SELECT * FROM table WHERE id > 4 ODER BY id ASC LIMIT 2
    #  - last 2 before 4 descending      ^ records with higher value than cursor
    #    -> SELECT * FROM table WHERE id > 4 ODER BY id ASC LIMIT 2
    #  but:                              ^ records with higher value than cursor
    #  - first 2 after 4 descending
    #    -> SELECT * FROM table WHERE id < 4 ODER BY id DESC LIMIT 2
    #  - last 2 before 4 ascending       ^ records with lower value than cursor
    #    -> SELECT * FROM table WHERE id < 4 ODER BY id DESC LIMIT 2
    #                                    ^ records with lower value than cursor
    #
    # @return [String] either '<' or '>'
    def filter_operator
      if paginate_forward?
        @order_direction == :asc ? '>' : '<'
      else
        @order_direction == :asc ? '<' : '>'
      end
    end

    # The value our relation is filtered by. This is either just the cursor's ID
    # if we use the default order, or it is the combination of the custom order
    # field's value and its ID, joined by a dash.
    #
    # @return [Integer, String]
    def filter_value
      return decoded_cursor_id unless custom_order_field?

      "#{decoded_cursor_field}-#{decoded_cursor_id}"
    end

    # Generate a cursor for the given record and ordering field. The cursor
    # encodes all the data required to then paginate based on it with the given
    # ordering field.
    #
    # If we only order by ID, the cursor doesn't need to include any other data.
    # But if we order by any other field, the cursor needs to include both the
    # value from this other field as well as the records ID to resolve the order
    # of duplicates in the non-ID field.
    #
    # @param record [ActiveRecord] Model instance for which we want the cursor
    # @return [String]
    def cursor_for_record(record)
      unencoded_cursor =
        if custom_order_field?
          [record[@order_field], record.id]
        else
          record.id
        end

      Base64.strict_encode64(unencoded_cursor.to_json)
    end

    # Decode the provided cursor. Either just returns the cursor's ID or in case
    # of pagination on any other field, returns a tuple of first the cursor
    # record's other field's value followed by its ID.
    #
    # @return [Integer, Array]
    def decoded_cursor
      memoize(:decoded_cursor) { JSON.parse(Base64.strict_decode64(@cursor)) }
    rescue ArgumentError, JSON::ParserError
      raise InvalidCursorError,
            "The given cursor `#{@cursor.inspect}` could not be decoded"
    end

    # Return the ID of the cursor's record. In case we use an ordering by ID,
    # this is all the data the cursor encodes. Otherwise, it's the second
    # element of the tuple encoded by the cursor.
    #
    # @return [Integer]
    def decoded_cursor_id
      return decoded_cursor unless decoded_cursor.is_a? Array

      decoded_cursor.last
    end

    # Return the value of the cursor's record's custom order field. Only exists
    # if the cursor was generated by a query with a custom order field.
    # Otherwise the cursor would only encode the ID and not be an array.

    # @raise [InvalidCursorError] in case the cursor is not a tuple
    # @return [Object]
    def decoded_cursor_field
      unless decoded_cursor.is_a? Array
        raise InvalidCursorError,
              "The given cursor `#{@cursor}` was decoded as "\
              "`#{decoded_cursor.inspect}` but could not be parsed"
      end

      decoded_cursor.first
    end

    # The SQL identifier of the column we need to consider for both ordering and
    # filtering.
    #
    # In case we have a custom field order, this is a concatenation
    # of the custom order field and the ID column joined by a dash. This is to
    # ensure uniqueness of records even if they might have duplicates in the
    # custom order field. If we don't have a custom order, it just returns a
    # reference to the table's ID column.
    #
    # This uses the fully qualified and escaped reference to the ID column to
    # prevent ambiguity in case of a query that uses JOINs and therefore might
    # have multiple ID columns.
    #
    # @return [String]
    def sql_column
      memoize :sql_column do
        escaped_table_name = @relation.quoted_table_name
        escaped_id_column = @relation.connection.quote_column_name(:id)

        id_column = "#{escaped_table_name}.#{escaped_id_column}"

        sql =
          if custom_order_field?
            "CONCAT(#{@order_field}, '-', #{id_column})"
          else
            id_column
          end

        Arel.sql(sql)
      end
    end

    # Ensure that the relation has the ID column and any potential `order_by`
    # column selected. These are required to generate the record's cursor and
    # therefore it's crucial that they are part of the selected fields.
    #
    # @return [ActiveRecord::Relation]
    def relation_with_cursor_fields
      return @relation if @relation.select_values.blank?

      relation = @relation

      unless @relation.select_values.include?(:id)
        relation = relation.select(:id)
      end

      if custom_order_field? && !@relation.select_values.include?(@order_field)
        relation = relation.select(@order_field)
      end

      relation
    end

    # The given relation with the right ordering applied. Takes custom order
    # columns as well as custom direction and pagination into account.
    #
    # @return [ActiveRecord::Relation]
    def sorted_relation
      relation_with_cursor_fields
        .reorder(sql_column => pagination_sorting.upcase)
    end

    # Applies the filtering based on the provided cursor and order column to the
    # sorted relation.
    #
    # @return [ActiveRecord::Relation]
    def filtered_and_sorted_relation
      memoize :filtered_and_sorted_relation do
        next sorted_relation if @cursor.blank?

        sorted_relation.where "#{sql_column} #{filter_operator} ?", filter_value
      end
    end

    # Ensures that given block is only executed exactly once and on subsequent
    # calls returns result from first execution. Useful for memoizing methods.
    #
    # @param key [Symbol]
    #   Name or unique identifier of the method that is being memoized
    # @yieldreturn [Object]
    # @return [Object] Whatever the block returns
    def memoize(key, &_block)
      return @memos[key] if @memos.key?(key)

      @memos[key] = yield
    end
  end
end
