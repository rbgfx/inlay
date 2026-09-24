# frozen_string_literal: true

module Inlay
  module Summary
    module_function

    def call(object, normalized)
      image = normalized.image || (normalized.frames&.first if normalized.frames)
      dimensions = image ? " #{image.width}x#{image.height}" : ""
      name = case object
      when Tessel::Image then "Tessel::Image"
      else object.class.name || object.class.to_s
      end
      frames = normalized.frames ? " frames=#{normalized.frames.length}" : ""
      "#<#{name}#{dimensions}#{frames}>"
    end
  end
end
