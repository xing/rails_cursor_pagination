# frozen_string_literal: true

module RailsCursorPagination
  # Use this Paginator class to effortlessly paginate through ActiveRecord
  # relations using cursor pagination. For more details on how this works,
  # read the top-level documentation of the `RailsCursorPagination` module.
  #
  # Usage:
  #     RailsCursorPagination::Paginator
  #       .new(relation)
  #       .records
  #
  class Paginator
    # @param [ActiveRecord::Relation] relation
    def initialize(relation)
      @relation = relation
    end

    # Get all records of the current page
    #
    # @return [Array<ActiveRecord>]
    def records
      @relation.first(5)
    end
  end
end
