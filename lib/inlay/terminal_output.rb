# frozen_string_literal: true

module Inlay
  module TerminalOutput
    module_function

    def protocol(output: $stdout, env: ENV)
      return :none unless Inlay.config.enabled
      return :none unless output.tty?
      return :none unless env["INLAY"] != "off"
      return :none if env["TERM"] == "dumb"

      selected = Termvas::Detector.protocol(env)
      return :none if selected == :blocks && env.key?("NO_COLOR")

      selected
    end

    def write(image, width: nil, height: nil, scale: :auto, protocol: nil, output: $stdout, env: ENV)
      selected = (protocol || self.protocol(output: output, env: env)).to_sym
      return false unless Inlay.config.enabled && output.tty? && selected != :none
      return false if selected == :blocks && env.key?("NO_COLOR")
      return false if image.width * image.height > Inlay.config.max_pixels

      image = Sizer.fit(image, width: width, height: height, scale: scale)
      bytes = image.bytes
      encoded = case selected.to_sym
      when :blocks then Termvas::Encoders::Blocks.encode(bytes, image.width, image.height)
      when :kitty then Termvas::Encoders::Kitty.encode(bytes, image.width, image.height, id: next_kitty_id)
      when :iterm2
        png = Tessel::PNG.encode(image)
        Termvas::Encoders::ITerm2.encode(png, width: image.width, height: image.height)
      when :sixel then Termvas::Encoders::Sixel.encode(bytes, image.width, image.height)
      else return false
      end
      output.write(encoded)
      output.write("\n")
      true
    end

    def next_kitty_id
      @kitty_id_lock ||= Mutex.new
      @kitty_id_lock.synchronize { @kitty_id = (@kitty_id.to_i % 2_147_483_647) + 1 }
    end
    private_class_method :next_kitty_id
  end
end
