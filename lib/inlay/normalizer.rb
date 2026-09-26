# frozen_string_literal: true

module Inlay
  Normalized = Struct.new(:image, :svg, :png, :frames, :fps, keyword_init: true)

  module Normalizer
    module_function

    def call(object, allow_path: false, seen: {})
      raise Error, "recursive to_inlay result" if seen[object.object_id]

      converted = Adapters.convert(object)
      return Normalized.new(image: converted) if converted.is_a?(Tessel::Image)
      return from_value(converted, allow_path: allow_path, seen: seen) unless converted.nil?

      return from_value(object.to_inlay, allow_path: allow_path, seen: seen.merge(object.object_id => true)) if object.respond_to?(:to_inlay)
      return from_value(object, allow_path: allow_path, seen: seen) if object.is_a?(Hash)
      return from_path(object) if allow_path && path_value?(object)

      Normalized.new
    end

    def terminal_image(normalized)
      return normalized.image if normalized.image
      return Tessel.decode(normalized.png, max_pixels: Inlay.config.max_pixels) if normalized.png.is_a?(String)
      if normalized.png.respond_to?(:call)
        value = normalized.png.call
        return value if value.is_a?(Tessel::Image)
        return Tessel.decode(value, max_pixels: Inlay.config.max_pixels) if value.is_a?(String)
        return call(value).image
      end
      return call(normalized.frames.first).image if normalized.frames&.any?

      nil
    end

    def from_value(value, allow_path:, seen:)
      raise Error, "recursive to_inlay result" if seen[value.object_id]
      return Normalized.new(image: value) if value.is_a?(Tessel::Image)
      return from_path(value) if allow_path && path_value?(value)
      return Normalized.new unless value.is_a?(Hash)

      data = value.each_with_object({}) { |(key, item), result| result[key.to_sym] = item if key.respond_to?(:to_sym) }
      if data[:frames]
        frames = Array(data[:frames])
        raise ArgumentError, "frames must not be empty" if frames.empty?
        raise TypeError, "frames must contain Tessel::Image values" unless frames.all? { |frame| frame.is_a?(Tessel::Image) }
        raise TypeError, "fps must be a finite positive number" unless data[:fps].is_a?(Numeric) && data[:fps].respond_to?(:positive?) && data[:fps].positive? && data[:fps].to_f.finite?

        return Normalized.new(frames: frames, fps: data[:fps])
      end
      raise TypeError, "png must be bytes or a callable" if data[:png] && !data[:png].is_a?(String) && !data[:png].respond_to?(:call)
      raise TypeError, "svg must be a String" if data[:svg] && !data[:svg].is_a?(String)

      Normalized.new(svg: data[:svg], png: data[:png])
    end
    private_class_method :from_value

    def from_path(value)
      bytes = value.is_a?(Pathname) ? File.binread(value) : String(value)
      Normalized.new(image: Tessel.decode(bytes, max_pixels: Inlay.config.max_pixels))
    end
    private_class_method :from_path

    def path_value?(value)
      value.is_a?(Pathname) || (value.is_a?(String) && IMAGE_EXTENSIONS.include?(File.extname(value).downcase) && File.file?(value))
    end
    IMAGE_EXTENSIONS = %w[.png .ppm .pnm .bmp].freeze
    private_class_method :path_value?
  end
end
