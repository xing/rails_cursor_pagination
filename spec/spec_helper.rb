# frozen_string_literal: true

require 'bundler/setup'
require 'rails_cursor_pagination'
require 'active_record'

# This dummy ActiveRecord class is used for testing
class Post < ActiveRecord::Base; end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Set up database to use for tests
  ActiveRecord::Base.logger = Logger.new(ENV['VERBOSE'] ? $stdout : nil)
  ActiveRecord::Migration.verbose = ENV['VERBOSE']

  ActiveRecord::Base.establish_connection(
    adapter: 'mysql2',
    database: 'rails_cursor_pagination_testing',
    host: ENV['DB_HOST'],
    user: ENV['DB_USER']
  )

  # Ensure we have an empty `posts` table with the right format
  ActiveRecord::Migration.drop_table :posts, if_exists: true

  ActiveRecord::Migration.create_table :posts do |t|
    t.string :author
    t.string :content
  end

  config.before(:each) { Post.delete_all }
  config.after(:each) { Post.delete_all }
end
