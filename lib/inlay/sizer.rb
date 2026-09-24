# frozen_string_literal: true

module Inlay
  module Sizer
    module_function

    def fit(image, width: nil, height: nil, scale: :auto, columns: nil, rows: nil)
      raise TypeError, "expected a Tessel::Image" unless image.is_a?(Tessel::Image)
      raise ArgumentError, "unknown scale mode: #{scale}" unless %i[auto fit pixel none].include?(scale)
      return image if image.width.zero? || image.height.zero?

      columns ||= width || Termvas::Terminal.new(alt_screen: false).size[0]
      width = [Integer(width || columns), Integer(columns)].min
      height = [Integer(height || Inlay.config.max_rows * 2), Inlay.config.max_rows * 2].min
      raise ArgumentError, "display dimensions must be positive" unless width.positive? && height.positive?
      pixel_scale = scale == :pixel || (scale == :auto && image.width <= 32 && image.height <= 32)
      max_factor = [width / [image.width, 1].max, height / [image.height, 1].max].min
      if pixel_scale && max_factor > 1
        return image.scale_nearest(image.width * max_factor, image.height * max_factor)
      end
      return image if image.width <= width && image.height <= height

      factor = [width.to_f / image.width, height.to_f / image.height, 1.0].min
      resize_area(image, [(image.width * factor).floor, 1].max, [(image.height * factor).floor, 1].max)
    end

    def resize_area(image, width, height)
      bytes = image.bytes
      output = String.new(capacity: width * height * 4, encoding: Encoding::BINARY)
      height.times do |y|
        top = y * image.height.to_f / height
        bottom = (y + 1) * image.height.to_f / height
        width.times do |x|
          left = x * image.width.to_f / width
          right = (x + 1) * image.width.to_f / width
          alpha = red = green = blue = area = 0.0
          (top.floor...bottom.ceil).each do |source_y|
            weight_y = [bottom, source_y + 1].min - [top, source_y].max
            (left.floor...right.ceil).each do |source_x|
              weight = weight_y * ([right, source_x + 1].min - [left, source_x].max)
              offset = (source_y * image.width + source_x) * 4
              a = bytes.getbyte(offset + 3)
              area += weight
              alpha += a * weight
              red += bytes.getbyte(offset) * a * weight
              green += bytes.getbyte(offset + 1) * a * weight
              blue += bytes.getbyte(offset + 2) * a * weight
            end
          end
          output << (alpha.zero? ? 0 : (red / alpha).round)
          output << (alpha.zero? ? 0 : (green / alpha).round)
          output << (alpha.zero? ? 0 : (blue / alpha).round)
          output << (alpha / area).round
        end
      end
      Tessel::Image.from_rgba(width, height, output)
    end
    private_class_method :resize_area
  end
end
