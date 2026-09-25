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

  it "rejects recursive or malformed animation protocols" do
    recursive = Object.new
    recursive.define_singleton_method(:to_inlay) { recursive }

    expect { described_class.normalize(recursive) }.to raise_error(Inlay::Error, /recursive/)
    expect { described_class.normalize({ frames: [Object.new], fps: 10 }) }.to raise_error(TypeError, /Tessel::Image/)
    expect { described_class.normalize({ frames: [image], fps: 0 }) }.to raise_error(TypeError, /positive/)
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
  end

  it "writes through the selected Termvas encoder only to a TTY" do
    output = Class.new(StringIO) { def tty? = true }.new

    expect(Inlay::TerminalOutput.write(image, width: 2, height: 1, protocol: :blocks, output: output, env: {})).to be(true)
    expect(output.string).to include("▀")
    expect(Inlay::TerminalOutput.write(image, width: 2, height: 1, protocol: :blocks, output: StringIO.new, env: {})).to be(false)
  end

  it "assigns each Kitty transmission a new image identifier" do
    output = Class.new(StringIO) { def tty? = true }.new
    2.times { Inlay::TerminalOutput.write(image, width: 2, height: 1, protocol: :kitty, output: output) }

    expect(output.string.scan(/i=(\d+)/).flatten.uniq.length).to eq(2)
  end

  it "shows a concise result when output is piped" do
    expect(described_class.show(image)).to eq("#<Tessel::Image 2x1>")
  end

  it "registers user adapters" do
    klass = Class.new
    described_class.register(klass) { image }

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
