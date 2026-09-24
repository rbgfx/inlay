# frozen_string_literal: true

module Inlay
  class Config
    attr_accessor :enabled
    attr_reader :max_rows, :max_pixels

    def initialize
      @enabled = true
      @max_rows = 24
      @max_pixels = 1_048_576
    end

    def max_rows=(value)
      @max_rows = positive_integer(value, :max_rows)
    end

    def max_pixels=(value)
      @max_pixels = positive_integer(value, :max_pixels)
    end

    private

    def positive_integer(value, name)
      number = Integer(value)
      raise ArgumentError, "#{name} must be positive" unless number.positive?

      number
    rescue ArgumentError, TypeError
      raise ArgumentError, "#{name} must be a positive integer"
    end
  end
end
