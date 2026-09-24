# frozen_string_literal: true

require "inlay"
require "mime/types"
require "iruby/display"
require "base64"
require "tempfile"
begin
  require "flipbook"
rescue LoadError
  # Animation falls back to its first frame when Flipbook is unavailable.
end

module Inlay
  module IRubyIntegration
    module_function

    def install
      return if @installed

      registry = IRuby::Display::Registry
      registry.match { |object| Inlay.displayable?(object) }
      registry.priority(100)
      registry.format(nil) { |object| render(object) }
      @installed = true
    end

    def render(object)
      normalized = Inlay.normalize(object)
      if normalized.svg
        ["image/svg+xml", normalized.svg]
      elsif normalized.png.is_a?(String)
        ["image/png", normalized.png]
      elsif normalized.frames
        animation(normalized.frames, normalized.fps)
      else
        ["image/png", Tessel::PNG.encode(Normalizer.terminal_image(normalized))]
      end
    end

    def animation(frames, fps)
      if defined?(Flipbook)
        Tempfile.create(["inlay", ".gif"]) do |file|
          Flipbook.write(file.path, frames, fps: fps)
          ["text/html", "<img alt=\"animation\" src=\"data:image/gif;base64,#{Base64.strict_encode64(File.binread(file.path))}\">"]
        end
      else
        ["image/png", Tessel::PNG.encode(frames.first)]
      end
    end
  end
end

Inlay::IRubyIntegration.install
