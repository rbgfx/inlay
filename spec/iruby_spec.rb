# frozen_string_literal: true

require "base64"
require "open3"
require "rbconfig"
require "inlay/iruby"
require "iruby/display"

RSpec.describe Inlay::IRubyIntegration do
  let(:image) { Tessel::Image.from_rgba(1, 1, [255, 0, 0, 255].pack("C*")) }

  it "registers once and renders images as PNG" do
    registry = IRuby::Display::Registry
    renderers = registry.renderer.length

    expect(described_class.install).to be(true)
    expect(registry.renderer.length).to eq(renderers)

    result = IRuby::Display.display(image)
    expect(Base64.decode64(result.fetch("image/png"))).to start_with("\x89PNG\r\n\x1a\n".b)
  end

  it "keeps IRuby's kernel and optional graphics gems out of normal loading" do
    script = <<~RUBY
      require "inlay"
      abort "IRuby loaded by inlay" if defined?(IRuby)
      abort "Inkplot loaded by inlay" if defined?(Inkplot)
      abort "Flipbook loaded by inlay" if defined?(Flipbook)
      require "inlay/iruby"
      abort "IRuby kernel loaded by display integration" if $LOADED_FEATURES.any? { |path| path.include?("iruby/kernel") || path.include?("ffi-rzmq") }
    RUBY
    _output, status = Open3.capture2e(RbConfig.ruby, "-I#{File.expand_path("../lib", __dir__)}", "-e", script)

    expect(status).to be_success, _output
  end

  it "renders Inkplot-style charts as SVG and offers PNG when requested" do
    expected_image = image
    chart_class = Class.new do
      define_method(:to_inlay) { { svg: "<svg>chart</svg>", png: -> { expected_image } } }
    end
    stub_const("Inkplot", Module.new)
    stub_const("Inkplot::Chart", chart_class)
    described_class.install

    chart = chart_class.new
    formats = IRuby::Display.display(chart)
    expect(formats.fetch("image/svg+xml")).to eq("<svg>chart</svg>")
    png = formats.fetch("image/png")
    expect(Base64.decode64(png)).to start_with("\x89PNG\r\n\x1a\n".b)
    expect(IRuby::Display.display(chart, format: "image/png").fetch("image/png")).to eq(png)
  end

  it "displays Flipbook animations as GIF data URIs" do
    writer = Module.new
    allow(writer).to receive(:write) do |path, frames, fps:|
      expect(frames).to eq([image, image])
      expect(fps).to eq(12)
      File.binwrite(path, "GIF89a")
    end
    stub_const("Flipbook", writer)

    formats = IRuby::Display.display({ frames: [image, image], fps: 12 })
    result = formats.fetch("text/html")
    expect(result).to include("data:image/gif;base64,", Base64.strict_encode64("GIF89a"))
  end

  it "falls back to the first animation frame when Flipbook is unavailable" do
    result = IRuby::Display.display({ frames: [image, image], fps: 12 }).fetch("image/png")
    expect(Base64.decode64(result)).to start_with("\x89PNG\r\n\x1a\n".b)
  end
end
