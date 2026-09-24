# frozen_string_literal: true

module Inlay
  module Adapters
    @adapters = {}

    module_function

    def register(klass, adapter)
      raise TypeError, "adapter key must be a Class or Module" unless klass.is_a?(Module)

      @adapters[klass] = adapter
    end

    def convert(object)
      pair = @adapters.find { |klass, _| object.is_a?(klass) }
      return pair.last.call(object) if pair

      return object if defined?(Tessel::Image) && object.is_a?(Tessel::Image)

      if defined?(RBGL::Engine::Framebuffer) && object.is_a?(RBGL::Engine::Framebuffer)
        return Tessel::Image.from_rgba(object.width, object.height, object.to_rgba_bytes)
      end

      if defined?(RBGL::Engine::Texture) && object.is_a?(RBGL::Engine::Texture)
        bytes = object.data.flat_map { |color| [color.r, color.g, color.b, color.a] }.pack("C*")
        return Tessel::Image.from_rgba(object.width, object.height, bytes)
      end

      if defined?(Inkplot::Chart) && object.is_a?(Inkplot::Chart)
        return object.to_inlay
      end

      nil
    end
  end
end
