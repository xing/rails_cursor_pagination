# RailsCursorPagination

This library allows to paginate through an `ActiveRecord` relation using cursor pagination.
It also supports ordering by any column on the relation in either ascending or descending order.

Cursor pagination allows to paginate results and gracefully deal with deletions / additions on previous pages.
Where a regular limit / offset pagination would jump in results if a record on a previous page gets deleted or added while requesting the next page, cursor pagination just returns the records following the one identified in the request.

To learn more about cursor pagination, check out the _"How does it work?"_ section below.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails_cursor_pagination'
```

And then execute:

```sh
$ bundle install
```

Or install it yourself as:

```sh
$ gem install rails_cursor_pagination
```

## Usage

Using it is very straight forward by just interfacing with the `RailsCursorPagination::Paginator` class.

Let's assume we have an `ActiveRecord` model called `Post` of which we want to fetch some data and then paginate through it.
Therefore, we first apply our scopes, `where` clauses or other functionality as usual:

```ruby
posts = Post.where(author: 'Jane')
```

And then we pass these posts to our paginator to fetch the first response page:

```ruby
RailsCursorPagination::Paginator.new(posts).fetch(with_total: true)
```

This will return a data structure similar to the following:
```
{
  total: 42,
  page_info: {
    has_previous_page: false,
    has_next_page: true,
    start_cursor: "MQ==",
    end_cursor: "MTA="
  },
  page: [
    { cursor: "MQ==", data: #<Post:0x00007fd7071b2ea8 @id=1> },
    { cursor: "Mg==", data: #<Post:0x00007fd7071bb738 @id=2> },
    ...,
    { cursor: "MTA=", data: #<Post:0x00007fd707238260 @id=10> }
  ]
}
```

Note that any ordering of the relation at this stage will be ignored by the gem.
Take a look at the next section _"Ordering"_ to see how you can have an order different than ascending IDs.
Read the _"The passed relation"_ to learn more about the relation that can be passed to the paginator.

As you saw in the request, `with_total` is an option.
If omitted, or set to `false`, the resulting hash will lack the `:total` key, but this will also cause one DB query less.
It is therefore recommended to only pass `with_total: true` when requested by the user.
So in the next examples we will also leave it away.

To then get the next result page, you simply need to pass the last cursor of the returned page item via:

```ruby
RailsCursorPagination::Paginator
  .new(posts, after: 'MTA=')
  .fetch
```

This will then fetch the next result page.
You can also just as easily paginate to previous pages by using `before` instead of `after` and using the first cursor of the current page.

```ruby
RailsCursorPagination::Paginator
  .new(posts, before: "MTE=")
  .fetch
```

By default, this will always return up to 10 results.
But you can also specify how many records should be returned.
You can pass `first: 2` to get the very first 2 records of the relation:

```ruby
RailsCursorPagination::Paginator
  .new(posts, first: 2)
  .fetch
```

Then, you can also combine `first` with `after` to get the first X records after a given one:

```ruby
RailsCursorPagination::Paginator
  .new(posts, first: 2, after: 'MTA=')
  .fetch
```

Or you can combine `before` with `last` to get the last X records before a given one:

```ruby
RailsCursorPagination::Paginator
  .new(posts, last: 2, before: 'MTA=')
  .fetch
```

### Ordering

As said, this gem ignores any previous ordering added to the passed relation.
But you can still paginate through relations with an order different than by ascending IDs.

### The `order` parameter

The first option you can pass is the `order` parameter.
It allows you to order the relation in reverse, descending.

```ruby
RailsCursorPagination::Paginator
  .new(posts, order: :desc)
  .fetch
```

The default is `:asc`, therefore this doesn't need to be passed.

### The `order_by` parameter

However, you can also specify a different column to order the results by.
Therefore, the `order_by` parameter needs to be passed.

```ruby
RailsCursorPagination::Paginator
  .new(posts, order_by: :author)
  .fetch
```

This will now order the records ascending by the `:author` field.
You can also combine the two:

```ruby
RailsCursorPagination::Paginator
  .new(posts, order_by: :author, order: :desc)
  .fetch
```

This will then sort the results by the author field in a descending order.
Of course, this can both be combined with `first`, `last`, `before`, and `after`.

**Important:**
If your app regularly orders by another column, you might want to add a database index for this.
Say that your order column is `author` then your index should be on `CONCAT(author, '-', id)`.

Please take a look at the _"How does it work?"_ to find out more why this is necessary.

### Configuration options

You can also change the default page size to a value that better fits the needs of your application.
So if a user doesn't request a given `first` or `last` value, the default amount of records is being returned.

To change the default, simply add an initializer to your app that does the following:

```ruby
RailsCursorPagination.configure do |config|
  config.default_page_size = 50
end
```

This would set the default page size to 50.
                       
### The passed relation

The relation passed to the `RailsCursorPagination::Paginator` needs to be an instance of an `ActiveRecord::Relation`.
So if you e.g. have a `Post` model that inherits from `ActiveRecord::Base`, you can initialize your paginator like this:

```ruby
RailsCursorPagination::Paginator
  .new(Post.all)
```

This would then paginate over all post records in your database.
              
#### Limiting the paginated records

As shown above, you can also apply `.where` clauses to filter your records before pagination:

```ruby
RailsCursorPagination::Paginator
  .new(Post.where(author: 'Jane'))
```

This would only paginate over Jane's records.
         
#### Limiting the queried fields 

You can also use `.select` to limit the fields that are requested from the database.
If, for example, your post contains a very big `content` field that you don't want to return on the paginated index endpoint, you can select to only get the fields relevant to you:

```ruby
RailsCursorPagination::Paginator
  .new(Post.select(:id, :author))
```

One important thing to note is that the ID of the record _will always be returned_, whether you selected it or not.
This is due to how the cursor is generated.
It requires the record's ID to always be present.
Therefore, even if it is not selected by you, it will be added to the query.

The same goes for any field that is specified via `order_by:`, this field is also required for building the cursor and will therefore automatically be requested from the database.

## How does it work?

The _cursor_ that we use for the `before` or `after` query encodes a value that uniquely identifies a given row _for the requested order_.
Then, based on this cursor, you can request the _"`n` **first** records **after** the cursor"_ (forward-pagination) or the _"`n` **last** records **before** the cursor"_ (backward-pagination).

As an example, assume we have a table called "posts" with this data:

| id | author |
|----|--------|
| 1  | Jane   |
| 2  | John   |
| 3  | John   |
| 4  | Jane   |
| 5  | Jane   |
| 6  | John   |
| 7  | John   |

Now if we make a basic request without any `first`/`after`, `last`/`before`, custom `order` or `order_by` column, this will just request the first page of this relation.

```ruby
RailsCursorPagination::Paginator
  .new(relation)
  .fetch
```

Assume that our default page size here is 2 and we would get a query like this:

```sql
SELECT *
FROM "posts"
ORDER BY "posts"."id" ASC
LIMIT 2
```

This will return the first page of results, containing post #1 and #2.
Since no custom order is defined, each item in the returned collection will have a cursor that only encodes the record's ID.

If we want to now request the next page, we can pass in the cursor of record #2 which would be `"Mg=="`.
So now we can request the next page by calling:

```ruby
RailsCursorPagination::Paginator
  .new(relation, first: 2, after: "Mg==")
  .fetch
```

And this will decode the given cursor and issue a query like:

```sql
SELECT *
FROM "posts"
WHERE "posts"."id" > 2
ORDER BY "posts"."id" ASC
LIMIT 2
```

Which would return posts #3 and #4.
If we now want to paginate back, we can request the posts that came before the first post, whose cursor would be `"Mw=="`:

```ruby
RailsCursorPagination::Paginator
  .new(relation, last: 2, before: "Mw==")
  .fetch
```

Since we now paginate backward, the resulting SQL query needs to be flipped around to get the last two records that have an ID smaller than the given one:

```sql
SELECT *
FROM "posts"
WHERE "posts"."id" < 3
ORDER BY "posts"."id" DESC
LIMIT 2
```

This would return posts #2 and #1.
Since we still requested them in ascending order, the result will be reversed before it is returned.

Now, in case that the user wants to order by a column different than the ID, we require this information in our cursor.
Therefore, when requesting the first page like this:

```ruby
RailsCursorPagination::Paginator
  .new(relation, order_by: :author)
  .fetch
```

This will issue the following SQL query:

```sql
SELECT *
FROM "posts"
ORDER BY CONCAT(author, '-', "posts"."id") ASC
LIMIT 2
```

As you can see, this will now order by a concatenation of the requested column, a dash `-`, and the ID column.
Ordering only the author is not enough since we cannot know if the custom column only has unique values.
And we need to guarantee the correct order of ambiguous records independent of the direction of ordering.
This unique order is the basis of being able to paginate forward and backward repeatedly and getting the correct records.

The query will then return records #1 and #4.
But the cursor for these records will also be different to the previous query where we ordered by ID only.
It is important that the cursor encodes all the data we need to uniquely identify a row and filter based upon it.
Therefore, we need to encode the same information as we used for the ordering in our SQL query.
Hence, the cursor for pagination with a custom column contains a tuple of data, the first record being the custom order column followed by the record's ID.

Therefore, the cursor of record #4 will encode `['Jane', 4]`, which yields this cursor: `"WyJKYW5lIiw0XQ=="`.

If we now want to request the next page via:

```ruby
RailsCursorPagination::Paginator
  .new(relation, order_by: :author, first: 2, after: "WyJKYW5lIiw0XQ==")
  .fetch
```

We get this SQL query:

```sql
SELECT *
FROM "posts"
WHERE CONCAT(author, '-', "posts"."id") > 'Jane-4'
ORDER BY CONCAT(author, '-', "posts"."id") ASC
LIMIT 2
```

You can see how the cursor is being translated into the WHERE clause to uniquely identify the row and properly filter based on this.
We will get the records #5 and #2 as response.

As you can see, when using a custom `order_by`, the concatenation is used for both filtering and ordering.
Therefore, it is recommended to add an index for columns that are frequently used for ordering.
In our test case we would want to add an index for `CONCAT(author, '-', id)`.

## Development

Make sure you have MySQL installed on your machine and create a database with the name `rails_cursor_pagination_testing`.

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `rake spec` to run the tests.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://source.xing.com/communities-team/rails_cursor_pagination.
This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://source.xing.com/communities-team/rails_cursor_pagination/blob/master/CODE_OF_CONDUCT.md).

If you open a pull request, please make sure to also document your changes in the `CHANGELOG.md`.
This way, your change can be properly announced in the next release.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the RailsCursorPagination project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/rails_cursor_pagination/blob/master/CODE_OF_CONDUCT.md).
