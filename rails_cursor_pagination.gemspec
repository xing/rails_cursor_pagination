# frozen_string_literal: true

require_relative 'lib/rails_cursor_pagination/version'

Gem::Specification.new do |spec|
  spec.name = 'rails_cursor_pagination'
  spec.version = RailsCursorPagination::VERSION
  spec.authors = ['Nicolas Fricke']
  spec.email = ['mail@nicolasfricke.com']

  spec.summary =
    'Add cursor pagination to your ActiveRecord backed application.'
  spec.description =
    'This library is an implementation of cursor pagination for ActiveRecord '\
    'relations. Where a regular limit & offset pagination has issues with '\
    'items that are being deleted from or added to the collection on previous '\
    'pages, cursor pagination will continue to offer a stable set regardless '\
    'of changes to the base relation.'
  spec.homepage = 'https://github.com/xing/rails_cursor_pagination'
  spec.license = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.5.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # By manually choosing what files to distribute we ensure that our gem is as
  # small as possible while still containing all relevant code and documentation
  # (as part of e.g. the README.md) as well as licensing information.
  spec.files = Dir.glob(%w[
                          lib/**/*
                          CHANGELOG.md
                          CODE_OF_CONDUCT.md
                          LICENSE.txt
                          README.md
                        ])
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 5.0'
end
