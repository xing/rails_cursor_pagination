# frozen_string_literal: true

module RailsCursorPagination
  # For internal use - this ParameterValidation class is used to validate
  # the inputs on the different classes of the library
  #
  # Usage:
  #     RailsCursorPagination::ParameterValidation
  #       .new(:type, ActiveRecord::Relation)
  #       .validate!({ argument_name: argument_value })
  #
  class ParameterValidation
    # Generic error that gets raised when invalid parameters are passed to the
    # Paginator initializer
    class ParameterError < Error; end

    def initialize(validator_type, *configuration)
      @validator_type = validator_type
      @configuration = configuration
    end

    def validate!(attributes)
      case @validator_type
      when :type
        validate_type!(attributes)
      when :use_only_one
        use_only_one!(attributes)
      when :use_together
        use_together!(attributes)
      when :positive_or_nil
        positive_or_nil!(attributes)
      when :in_values
        in_values!(attributes)
      else
        raise ParameterError,
              "Called library with wrong type: `#{@validator_type}`"
      end
    end

    private

    def validate_type!(attributes)
      type = @configuration.first
      value = attributes.values.first
      attribute_name = attributes.keys.first

      return if value.is_a?(type)

      raise ParameterError,
            "`#{attribute_name}` must be an #{type}, but was "\
            "the #{value.class} `#{value.inspect}`"
    end

    def in_values!(attributes)
      attribute_name = attributes.keys.first
      attribute_value = attributes.values.first
      values = @configuration.first

      return if values.include?(attribute_value)

      valid_values = if values.size == 2
                       "either #{values[0].inspect} or #{values[1].inspect}"
                     else
                       "in #{values.map(&:inspect).join(' ')}"
                     end

      raise ParameterError,
            "`#{attribute_name}` must be #{valid_values}, " \
            "but was `#{attribute_value}`"
    end

    def use_only_one!(attributes)
      return unless attributes.values.all?(&:present?)

      first_attribute  = attributes.keys.first
      second_attribute = attributes.keys.last

      raise ParameterError,
            "`#{first_attribute}` cannot be combined with `#{second_attribute}`"
    end

    def use_together!(attributes)
      if attributes.values.none?(&:present?) ||
         attributes.values.all?(&:present?)
        return
      end

      first_attribute  = attributes.keys.first
      second_attribute = attributes.keys.last

      raise ParameterError,
            "`#{first_attribute}` must be combined with `#{second_attribute}`"
    end

    def positive_or_nil!(attributes)
      attribute = attributes.values.first
      attribute_key = attributes.keys.first

      return unless attribute.present? && attribute.negative?

      raise ParameterError,
            "`#{attribute_key}` cannot be negative, but was `#{attribute}`"
    end
  end
end
