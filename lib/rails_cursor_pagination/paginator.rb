# frozen_string_literal: true

module RailsCursorPagination
  # Use this Paginator class to effortlessly paginate through ActiveRecord
  # relations using cursor pagination. For more details on how this works,
  # read the top-level documentation of the `RailsCursorPagination` module.
  #
  # Usage:
  #     RailsCursorPagination::Paginator
  #       .new(relation, order_by: :author, first: 2, after: "WyJKYW5lIiw0XQ==")
  #       .records
  #
  class Paginator
    class ParameterError < Error; end

    DEFAULT_PAGE_SIZE = 5

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
    # @param order_by [Symbol, String]
    #   Column to order by. If none is provided, will default to ID column.
    #   NOTE: this will cause an SQL `CONCAT` query. Therefore, you might want
    #   to add an index to your database: `CONCAT(<order_by_field>, '-', id)`
    # @param order [Symbol]
    #   Ordering to apply, either `:asc` or `:desc`. Defaults to `:asc`.
    #
    # @raise [RailsCursorPagination::Paginator::ParameterError]
    #   If any parameter is not valid
    def initialize(relation, first: nil, after: nil, last: nil, before: nil,
                   order_by: :id, order: :asc)
      ensure_valid_params!(relation, first, after, last, before, order)

      @order_field = order_by
      @order_direction = order
      @relation = relation

      @cursor = before || after
      @is_forward_pagination = before.blank?

      @page_size =
        first ||
        last ||
        DEFAULT_PAGE_SIZE
    end

    # Get all records of the current page
    #
    # @return [Array<ActiveRecord>]
    def records
      @relation.first(@page_size)
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
  end
end
