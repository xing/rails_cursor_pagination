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
# As an example, assume we have a table called "posts" with this data:
#
#     | id | author |
#     |----|--------|
#     | 1  | Jane   |
#     | 2  | John   |
#     | 3  | John   |
#     | 4  | Jane   |
#     | 5  | Jane   |
#     | 6  | John   |
#     | 7  | John   |
#
# Now if we make a basic request without any `first`/`after`, `last`/`before`,
# custom `order` or `order_by` column, this will just request the first page
# of this relation.
#
#     RailsCursorPagination::Paginator
#       .new(relation)
#       .fetch
#
# Assume that our default page size here is 2 and we would get a query like
# this:
#
#     SELECT *
#     FROM "posts"
#     ORDER BY "posts"."id" ASC
#     LIMIT 2
#
# This will return the first page of results, containing post #1 and #2. Since
# no custom order is defined, each item in the returned collection will have a
# cursor that only encodes the record's ID.
#
# If we want to now request the next page, we can pass in the cursor of record
# #2 which would be "Mg==". So now we can request the next page by calling:
#
#     RailsCursorPagination::Paginator
#       .new(relation, first: 2, after: "Mg==")
#       .fetch
#
# And this will decode the given cursor and issue a query like:
#
#     SELECT *
#     FROM "posts"
#     WHERE "posts"."id" > 2
#     ORDER BY "posts"."id" ASC
#     LIMIT 2
#
# Which would return posts #3 and #4. If we now want to paginate back, we can
# request the posts that came before the first post, whose cursor would be
# "Mw==":
#
#     RailsCursorPagination::Paginator
#       .new(relation, last: 2, before: "Mw==")
#       .fetch
#
# Since we now paginate backward, the resulting SQL query needs to be flipped
# around to get the last two records that have an ID smaller than the given
# one:
#
#     SELECT *
#     FROM "posts"
#     WHERE "posts"."id" < 3
#     ORDER BY "posts"."id" DESC
#     LIMIT 2
#
# This would return posts #2 and #1. Since we still requested them in
# ascending order, the result will be reversed before it is returned.
#
# Now, in case that the user wants to order by a column different than the ID,
# we require this information in our cursor. Therefore, when requesting the
# first page like this:
#
#     RailsCursorPagination::Paginator
#       .new(relation, order_by: :author)
#       .fetch
#
# This will issue the following SQL query:
#
#     SELECT *
#     FROM "posts"
#     ORDER BY "posts"."author" ASC, "posts"."id" ASC
#     LIMIT 2
#
# As you can see, this will now order by the author first, and if two records
# have the same author it will order them by ID. Ordering only the author is not
# enough since we cannot know if the custom column only has unique values.
# And we need to guarantee the correct order of ambiguous records independent
# of the direction of ordering. This unique order is the basis of being able
# to paginate forward and backward repeatedly and getting the correct records.
#
# The query will then return records #1 and #4. But the cursor for these
# records will also be different to the previous query where we ordered by ID
# only. It is important that the cursor encodes all the data we need to
# uniquely identify a row and filter based upon it. Therefore, we need to
# encode the same information as we used for the ordering in our SQL query.
# Hence, the cursor for pagination with a custom column contains a tuple of
# data, the first record being the custom order column followed by the
# record's ID.
#
# Therefore, the cursor of record #4 will encode `['Jane', 4]`, which yields
# this cursor: "WyJKYW5lIiw0XQ==".
#
# If we now want to request the next page via:
#
#     RailsCursorPagination::Paginator
#       .new(relation, order_by: :author, first: 2, after: "WyJKYW5lIiw0XQ==")
#       .fetch
#
# We get this SQL query:
#
#     SELECT *
#     FROM "posts"
#     WHERE (author > 'Jane' OR (author = 'Jane') AND ("posts"."id" > 4))
#     ORDER BY "posts"."author" ASC, "posts"."id" ASC
#     LIMIT 2
#
# You can see how the cursor is being used by the WHERE clause to uniquely
# identify the row and properly filter based on this. We only want to get
# records that either have a name that is alphabetically after `"Jane"` or
# another `"Jane"` record with an ID that is higher than `4`. We will get the
# records #5 and #2 as response.
#
# When using a custom `order_by`, this affects both filtering as well as
# ordering. Therefore, it is recommended to add an index for columns that are
# frequently used for ordering. In our test case we would want to add a compound
# index for the `(author, id)` column combination. Databases like MySQL and
# Postgres are able to then use the leftmost part of the index, in our case
# `author`, by its own _or_ can use it combined with the `id` index.
#
module RailsCursorPagination
  class Error < StandardError; end

  # Generic error that gets raised when invalid parameters are passed to the
  # pagination
  class ParameterError < Error; end

  # Error that gets raised if a cursor given as `before` or `after` cannot be
  # properly parsed
  class InvalidCursorError < ParameterError; end

  require_relative 'rails_cursor_pagination/version'

  require_relative 'rails_cursor_pagination/configuration'

  require_relative 'rails_cursor_pagination/paginator'

  require_relative 'rails_cursor_pagination/cursor'

  class << self
    # Allows to configure this gem. Currently supported configuration values
    # are:
    #  * default_page_size - defines how many items are returned when not
    #                        passing an explicit `first` or `last` parameter
    #
    # Usage:
    #
    #    RailsCursorPagination.configure do |config|
    #      config.default_page_size = 42
    #    end
    #
    # @yield [config] Yields a block to configure the gem as explained above
    # @yieldparam config [RailsCursorPagination::Configuration]
    #   Configuration instance that can be used to set up this gem
    def configure(&_block)
      yield(Configuration.instance)
    end
  end
end
