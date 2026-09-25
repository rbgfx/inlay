# frozen_string_literal: true

require "base64"
require "inlay"
require "iruby/display"
require "mime/types"

module Inlay
  module IRubyIntegration
    module_function

    module MimeBundle
      def to_iruby_mimebundle(include: [])
        return super if defined?(super)

        Inlay::IRubyIntegration.mimebundle(self, include: include)
      end
    end

    def install
      unless @registered
        registry = IRuby::Display::Registry
        registry.match { |object| Inlay.displayable?(object) }
        registry.format("text/html") { |object| html(object) }
        registry.format("image/svg+xml") { |object| svg(object) }
        registry.format("image/png") { |object| png(object) }
        @registered = true
      end
      install_mimebundle
      true
    end

    def html(object)
      animation_html(Inlay.normalize(object))
    rescue StandardError
      nil
    end

    def svg(object)
      Inlay.normalize(object).svg
    rescue StandardError
      nil
    end

    def png(object)
      png_content(Inlay.normalize(object))
    rescue LoadError, StandardError
      nil
    end

    def mimebundle(object, include: [])
      normalized = Inlay.normalize(object)
      formats = {}
      formats["text/html"] = animation_html(normalized) if normalized.frames
      formats["image/svg+xml"] = normalized.svg if normalized.svg
      png_bytes = png_content(normalized)
      formats["image/png"] = Base64.strict_encode64(png_bytes) if png_bytes
      formats.select! { |mime, _| include.empty? || include.include?(mime) }
      [formats, {}]
    rescue StandardError
      [{}, {}]
    end

    def install_mimebundle
      classes = [Tessel::Image]
      classes << RBGL::Engine::Framebuffer if defined?(RBGL::Engine::Framebuffer)
      classes << RBGL::Engine::Texture if defined?(RBGL::Engine::Texture)
      classes << Inkplot::Chart if defined?(Inkplot::Chart)
      classes.uniq.each do |klass|
        klass.prepend(MimeBundle) unless klass.ancestors.include?(MimeBundle)
      end
    end
    private_class_method :install_mimebundle

    def animation_html(normalized)
      return unless normalized.frames

      writer = flipbook_writer
      return unless writer

      require "tempfile"
      gif = Tempfile.create(["inlay-", ".gif"]) do |file|
        writer.write(file.path, normalized.frames, fps: normalized.fps)
        File.binread(file.path)
      end
      "<img alt=\"Animation with #{normalized.frames.length} frames\" src=\"data:image/gif;base64,#{Base64.strict_encode64(gif)}\">"
    rescue LoadError, StandardError
      nil
    end

    def png_content(normalized)
      image = normalized.image || normalized.frames&.first
      return Tessel::PNG.encode(image) if image

      value = normalized.png
      value = value.call if value.respond_to?(:call)
      return value if value.is_a?(String)
      return Tessel::PNG.encode(value) if value.is_a?(Tessel::Image)
    rescue LoadError, StandardError
      nil
    end
    private_class_method :animation_html, :png_content

    def flipbook_writer
      return Flipbook if defined?(Flipbook) && Flipbook.respond_to?(:write)

      require "flipbook"
      Flipbook if defined?(Flipbook) && Flipbook.respond_to?(:write)
    rescue LoadError => error
      raise unless error.path == "flipbook"
    end
    private_class_method :flipbook_writer
  end
end

Inlay::IRubyIntegration.install
