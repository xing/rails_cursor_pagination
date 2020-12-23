# frozen_string_literal: true

module RailsCursorPagination
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
