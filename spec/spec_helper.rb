# frozen_string_literal: true

require 'bundler/setup'
require 'rails_cursor_pagination'
require 'active_record'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  ActiveRecord::Base.logger = Logger.new(ENV['VERBOSE'] ? STDOUT : nil)
  ActiveRecord::Migration.verbose = ENV['VERBOSE']

  # migrations
  ActiveRecord::Base.establish_connection adapter: 'sqlite3',
                                          database: ':memory:'

  ActiveRecord::Migration.create_table :posts do |t|
    t.string :author
  end

  class Post < ActiveRecord::Base; end
end
