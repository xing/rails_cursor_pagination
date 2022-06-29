# frozen_string_literal: true

require 'singleton'

module RailsCursorPagination
  # Configuration class to set the default gem settings. Accessible via
  # `RailsCursorPagination.configure`.
  #
  # Usage:
  #
  #    RailsCursorPagination.configure do |config|
  #      config.default_page_size = 42
  #      config.max_page_size = 100
  #    end
  #
  class Configuration
    include Singleton

    attr_accessor :default_page_size, :max_page_size

    # Ensure the default values are set on first initialization
    def initialize
      reset!
    end

    # Reset all values to their defaults
    def reset!
      @default_page_size = 10
      @max_page_size = nil
    end
  end
end
