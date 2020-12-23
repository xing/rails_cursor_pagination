# frozen_string_literal: true

module RailsCursorPagination
  class Error < StandardError; end

  require_relative 'rails_cursor_pagination/version'

  require_relative 'rails_cursor_pagination/paginator'
end
