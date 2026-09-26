# frozen_string_literal: true

RSpec.describe Inlay do
  let(:image) { Tessel::Image.from_rgba(2, 1, [255, 0, 0, 255, 0, 0, 255, 255].pack("C*") ) }

  it "normalizes images and supported to_inlay values" do
    value = Object.new
    expected_image = image
    value.define_singleton_method(:to_inlay) { { svg: "<svg/>", png: -> { expected_image } } }

    expect(described_class.displayable?(image)).to be(true)
    expect(described_class.normalize(value).svg).to eq("<svg/>")
    expect(described_class.normalize(value).png.call).to equal(image)
  end

  it "normalizes PNG byte strings" do
    png = Tessel::PNG.encode(image)

    expect(described_class.normalize({ png: png }).png).to equal(png)
    expect(Inlay::Normalizer.terminal_image(described_class.normalize({ png: png })).bytes).to eq(image.bytes)
  end

  it "rejects recursive or malformed animation protocols" do
    recursive = Object.new
    recursive.define_singleton_method(:to_inlay) { recursive }

    expect { described_class.normalize(recursive) }.to raise_error(Inlay::Error, /recursive/)
    expect { described_class.normalize({ frames: [Object.new], fps: 10 }) }.to raise_error(TypeError, /Tessel::Image/)
    expect { described_class.normalize({ frames: [image], fps: 0 }) }.to raise_error(TypeError, /positive/)
    expect { described_class.normalize({ frames: [image], fps: Float::INFINITY }) }.to raise_error(TypeError, /positive/)
  end

  it "does not interpret ordinary strings as paths, even when they exist" do
    file = Tempfile.new(["inlay", ".txt"])
    file.write("not an image")
    file.close

    expect(described_class.displayable?(file.path)).to be(false)
    expect(described_class.show(file.path)).to eq("#<String>")
    expect { described_class.normalize(Pathname(file.path), allow_path: true) }.to raise_error(Tessel::UnsupportedError)
  ensure
    file&.unlink
  end

  it "limits and scales pixels while preserving alpha-aware averages" do
    fitted = Inlay::Sizer.fit(image, width: 1, height: 1)

    expect([fitted.width, fitted.height]).to eq([1, 1])
    expect(fitted.bytes.bytes).to eq([128, 0, 128, 255])
    expect(Inlay::Sizer.fit(image, width: 8, height: 8, scale: :pixel).width).to eq(8)
    expect(Inlay::Sizer.fit(image, width: 8, height: 8).width).to eq(8)
    tall_image = Tessel::Image.from_rgba(1, 100, ([0, 0, 0, 255] * 100).pack("C*"))
    expect(Inlay::Sizer.fit(tall_image, width: 100, height: 100).height).to be <= Inlay.config.max_rows * 2
  end

  it "fits protocol images to terminal cell dimensions" do
    large_image = Tessel::Image.from_rgba(100, 100, ([0, 0, 0, 255] * 10_000).pack("C*"))
    env = { "COLUMNS" => "80", "LINES" => "24", "TERMVAS_CELL_WIDTH" => "10", "TERMVAS_CELL_HEIGHT" => "20" }

    blocks = Inlay::Sizer.fit(large_image, scale: :fit, protocol: :blocks, env: env)
    kitty = Inlay::Sizer.fit(large_image, scale: :fit, protocol: :kitty, env: env)
    expect([blocks.width, blocks.height]).to eq([48, 48])
    expect([kitty.width, kitty.height]).to eq([100, 100])

    oversized_cells = { "COLUMNS" => "80", "LINES" => "24", "TERMVAS_CELL_WIDTH" => "4096", "TERMVAS_CELL_HEIGHT" => "4096" }
    bounded = Inlay::Sizer.fit(image, scale: :pixel, protocol: :kitty, env: oversized_cells)
    expect(bounded.width * bounded.height).to be <= Inlay.config.max_pixels
  end

  it "writes through the selected Termvas encoder only to a TTY" do
    output = Class.new(StringIO) { def tty? = true }.new

    expect(Inlay::TerminalOutput.write(image, width: 2, height: 1, protocol: :blocks, output: output, env: {})).to be(true)
    expect(output.string).to include("▀")
    expect(output.string).to end_with("\n")
    expect(Inlay::TerminalOutput.write(image, width: 2, height: 1, protocol: :blocks, output: StringIO.new, env: {})).to be(false)
    expect(Inlay::TerminalOutput.protocol(output: output, env: { "TERM" => "dumb" })).to eq(:none)
    expect(Inlay::TerminalOutput.write(image, width: 2, height: 1, protocol: :blocks, output: output, env: { "NO_COLOR" => "1" })).to be(false)
    expect(Inlay::TerminalOutput.write(image, width: 2, height: 1, protocol: :blocks, output: output, env: { "INLAY" => "off" })).to be(false)
  end

  it "supports each Termvas image encoder" do
    %i[blocks kitty iterm2 sixel].each do |protocol|
      output = Class.new(StringIO) { def tty? = true }.new
      expect(Inlay::TerminalOutput.write(image, width: 2, height: 1, protocol: protocol, output: output, env: {})).to be(true)
    end
  end

  it "does not send empty images to terminal encoders" do
    output = Class.new(StringIO) { def tty? = true }.new
    empty = Tessel::Image.from_rgba(0, 1, "")

    expect(Inlay::TerminalOutput.write(empty, protocol: :iterm2, output: output, env: {})).to be(false)
    expect(output.string).to be_empty
  end

  it "honors the enabled flag and maximum pixel limit" do
    output = Class.new(StringIO) { def tty? = true }.new
    enabled = Inlay.config.enabled
    max_pixels = Inlay.config.max_pixels

    Inlay.config.enabled = false
    expect(Inlay::TerminalOutput.write(image, protocol: :blocks, output: output, env: {})).to be(false)
    Inlay.config.enabled = true
    Inlay.config.max_pixels = 1
    expect(Inlay::TerminalOutput.write(image, protocol: :blocks, output: output, env: {})).to be(false)
  ensure
    Inlay.config.enabled = enabled
    Inlay.config.max_pixels = max_pixels
  end

  it "assigns each Kitty transmission a new image identifier" do
    output = Class.new(StringIO) { def tty? = true }.new
    2.times { Inlay::TerminalOutput.write(image, width: 2, height: 1, protocol: :kitty, output: output, env: {}) }

    expect(output.string.scan(/i=(\d+)/).flatten.uniq.length).to eq(2)
  end

  it "shows a concise result when output is piped" do
    expect(described_class.show(image)).to eq("#<Tessel::Image 2x1>")
    expect(described_class.show({ frames: [image, image], fps: 12 })).to eq("#<Hash 2x1 frames=2>")
  end

  it "sends the first animation frame to the terminal and summarizes all frames" do
    allow(Inlay::TerminalOutput).to receive(:write) do |frame, **options|
      expect(frame).to equal(image)
      expect(options[:protocol]).to eq(:kitty)
      true
    end

    expect(Inlay.show({ frames: [image, image], fps: 12 }, protocol: :kitty)).to eq("#<Hash 2x1 frames=2>")
  end

  it "provides the optional Kernel helper" do
    require "inlay/kernel"

    expect(inlay(image)).to eq("#<Tessel::Image 2x1>")
  end

  it "adapts optional RBGL buffers only when their classes are loaded" do
    engine = Module.new
    framebuffer_class = Class.new do
      def width = 1
      def height = 1
      def to_rgba_bytes = [1, 2, 3, 4].pack("C*")
    end
    color_class = Struct.new(:r, :g, :b, :a)
    texture_class = Class.new do
      define_method(:width) { 1 }
      define_method(:height) { 1 }
      define_method(:data) { [color_class.new(5, 6, 7, 8)] }
    end
    stub_const("RBGL", Module.new)
    stub_const("RBGL::Engine", engine)
    stub_const("RBGL::Engine::Framebuffer", framebuffer_class)
    stub_const("RBGL::Engine::Texture", texture_class)

    expect(described_class.normalize(framebuffer_class.new).image.bytes.bytes).to eq([1, 2, 3, 4])
    expect(described_class.normalize(texture_class.new).image.bytes.bytes).to eq([5, 6, 7, 8])
  end

  it "registers user adapters" do
    klass = Class.new
    adapter = proc { image }

    described_class.register(klass, &adapter)
    expect(described_class.normalize(klass.new).image).to equal(image)
  end

  it "wraps IRB's active inspector and can restore it" do
    require "inlay/irb"
    wrapper = IRB.conf[:INSPECT_MODE]
    original = Inlay::IRBIntegration.original
    output = StringIO.new
    result = wrapper.inspect_value(image, output)

    expect(output.string).to include("#<Tessel::Image 2x1>")
    expect(result).to equal(output)
    expect { described_class.irb_uninstall! }.to change { IRB.conf[:INSPECT_MODE] }.to(original)
    described_class.irb_install!
    expect(described_class.irb_install!).to be(true)
  end

  it "runs the wrapped inspector initializer" do
    require "inlay/irb"
    previous = Inlay::IRBIntegration.original
    initialized = false
    original = IRB::Inspector.new(proc { |value| value.inspect }, proc { initialized = true })
    IRB.conf[:INSPECT_MODE] = original

    described_class.irb_install!

    expect(initialized).to be(true)
  ensure
    Inlay::IRBIntegration.uninstall
    IRB.conf[:INSPECT_MODE] = previous
    described_class.irb_install!
  end

  it "caches the terminal protocol when the IRB integration is installed" do
    require "inlay/irb"
    allow(Inlay::TerminalOutput).to receive(:protocol).and_return(:kitty)
    described_class.irb_install!
    selected = nil
    allow(Inlay::TerminalOutput).to receive(:write) do |_image, **options|
      selected = options[:protocol]
      false
    end

    Inlay::IRBIntegration.wrapper.inspect_value(image, StringIO.new)

    expect(selected).to eq(:kitty)
  ensure
    described_class.irb_install! if defined?(IRB)
  end

  it "passes Pry's configured printer a rendered summary" do
    require "inlay/pry"
    received = []
    old_printer = Pry.config.print
    Pry.config.print = proc { |output, value, _pry| received << value; output << value.to_s }
    Inlay::PryIntegration.install
    output = StringIO.new
    Pry.config.print.call(output, image, Object.new)

    expect(received).to eq(["#<Tessel::Image 2x1>"])
    expect(output.string).to eq("#<Tessel::Image 2x1>")
  ensure
    Inlay::PryIntegration.uninstall if defined?(Inlay::PryIntegration)
    Pry.config.print = old_printer if defined?(Pry) && old_printer
  end

end
