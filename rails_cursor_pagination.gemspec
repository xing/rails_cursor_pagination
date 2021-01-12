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
  spec.homepage =
    'https://source.xing.com/communities-team/rails_cursor_pagination'
  spec.license = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.5.0')

  spec.metadata['allowed_push_host'] = 'https://gems.xing.com'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/releases"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added
  # into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0")
                     .reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 5.0'
end
