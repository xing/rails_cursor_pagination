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
    # Create a new instance of the `RailsCursorPagination::Paginator`
    #
    # @param relation [ActiveRecord::Relation]
    #   Relation that will be paginated.
    # @param limit [Integer, nil]
    #   Number of records to return in pagination. Can be combined with either
    #   `after` or `before` as an alternative to `first` or `last`.
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
    #   NOTE: this will cause the query to filter on both the given column as
    #   well as the ID column. So you might want to add a compound index to your
    #   database similar to:
    #   ```sql
    #     CREATE INDEX <index_name> ON <table_name> (<order_by_field>, id)
    #   ```
    # @param order [Symbol, nil]
    #   Ordering to apply, either `:asc` or `:desc`. Defaults to `:asc`.
    #
    # @raise [RailsCursorPagination::ParameterError]
    #   If any parameter is not valid
    def initialize(relation, limit: nil, first: nil, after: nil, last: nil,
                   before: nil, order_by: nil, order: nil)
      order_by ||= :id
      order ||= :asc

      ensure_valid_params_values!(relation, order, limit, first, last)
      ensure_valid_params_combinations!(first, last, limit, before, after)

      @order_field = order_by
      @order_direction = order
      @relation = relation

      @cursor = before || after
      @is_forward_pagination = before.blank?

      @page_size =
        first ||
        last ||
        limit ||
        RailsCursorPagination::Configuration.instance.default_page_size

      if Configuration.instance.max_page_size &&
         Configuration.instance.max_page_size < @page_size
        @page_size = Configuration.instance.max_page_size
      end

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
        **(with_total ? { total: result.total } : {}),
        page_info: result.page_info,
        page: result.page
      }
    end

    def page_info
      result.page_info
    end

    def records
      result.records
    end

    private

    def result
      @result ||= Page.new(
        order_field: @order_field,
        order_direction: @order_direction,
        relation: @relation,
        cursor: @cursor,
        paginate_forward: @is_forward_pagination,
        page_size: @page_size
      )
    end

    # Ensure that the parameters of this service have valid values, otherwise
    # raise a `RailsCursorPagination::ParameterError`.
    #
    # @param relation [ActiveRecord::Relation]
    #   Relation that will be paginated.
    # @param order [Symbol]
    #   Must be :asc or :desc
    # @param limit [Integer, nil]
    #   Optional, must be positive
    # @param first [Integer, nil]
    #   Optional, must be positive
    # @param last [Integer, nil]
    #   Optional, must be positive
    #   with `first` or `limit`
    #
    # @raise [RailsCursorPagination::ParameterError]
    #   If any parameter is not valid
    def ensure_valid_params_values!(relation, order, limit, first, last)
      unless relation.is_a?(ActiveRecord::Relation)
        raise ParameterError,
              'The first argument must be an ActiveRecord::Relation, but was ' \
              "the #{relation.class} `#{relation.inspect}`"
      end
      unless %i[asc desc].include?(order)
        raise ParameterError,
              "`order` must be either :asc or :desc, but was `#{order}`"
      end
      if first.present? && first.negative?
        raise ParameterError, "`first` cannot be negative, but was `#{first}`"
      end
      if last.present? && last.negative?
        raise ParameterError, "`last` cannot be negative, but was `#{last}`"
      end
      if limit.present? && limit.negative?
        raise ParameterError, "`limit` cannot be negative, but was `#{limit}`"
      end

      true
    end

    # Ensure that the parameters of this service are combined in a valid way.
    # Otherwise raise a +RailsCursorPagination::ParameterError+.
    #
    # @param limit [Integer, nil]
    #   Optional, cannot be combined with `last` or `first`
    # @param first [Integer, nil]
    #   Optional, cannot be combined with `last` or `limit`
    # @param after [String, nil]
    #   Optional, cannot be combined with `before`
    # @param last [Integer, nil]
    #   Optional, requires `before`, cannot be combined
    #   with `first` or `limit`
    # @param before [String, nil]
    #   Optional, cannot be combined with `after`
    #
    # @raise [RailsCursorPagination::ParameterError]
    #   If parameters are combined in an invalid way
    def ensure_valid_params_combinations!(first, last, limit, before, after)
      if first.present? && last.present?
        raise ParameterError, '`first` cannot be combined with `last`'
      end
      if first.present? && limit.present?
        raise ParameterError, '`limit` cannot be combined with `first`'
      end
      if last.present? && limit.present?
        raise ParameterError, '`limit` cannot be combined with `last`'
      end
      if before.present? && after.present?
        raise ParameterError, '`before` cannot be combined with `after`'
      end
      if last.present? && before.blank?
        raise ParameterError, '`last` must be combined with `before`'
      end

      true
    end
  end
end
