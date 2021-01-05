# frozen_string_literal: true

# This library allows to paginate through a passed relation using a cursor
# and first/after or last/before parameters. It also supports ordering by
# any column on the relation in either ascending or descending order.
#
# Cursor pagination allows to paginate results and gracefully deal with
# deletions / additions on previous pages. Where a regular limit / offset
# pagination would jump in results if a record on a previous page gets deleted
# or added while requesting the next page, cursor pagination just returns the
# records following the one identified in the request.
#
# How this works is that it uses a "cursor", which is an encoded value that
# uniquely identifies a given row for the requested order. Then, based on
# this cursor, you can request the "n FIRST records AFTER the cursor"
# (forward-pagination) or the "n LAST records BEFORE the cursor" (backward-
# pagination).
#
module RailsCursorPagination
  class Error < StandardError; end

  require_relative 'rails_cursor_pagination/version'

  require_relative 'rails_cursor_pagination/paginator'
end
