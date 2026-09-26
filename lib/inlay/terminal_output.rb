# frozen_string_literal: true

module Inlay
  module TerminalOutput
    module_function

    def protocol(output: $stdout, env: ENV)
      return :none unless enabled?(output: output, env: env)

      selected = Termvas::Detector.protocol(env)
      return :none if selected == :blocks && env.key?("NO_COLOR")

      selected
    end

    def write(image, width: nil, height: nil, scale: :auto, protocol: nil, output: $stdout, env: ENV)
      selected = (protocol || self.protocol(output: output, env: env)).to_sym
      return false unless enabled?(output: output, env: env) && selected != :none
      return false if selected == :blocks && env.key?("NO_COLOR")
      return false if image.width * image.height > Inlay.config.max_pixels
      return false if image.width.zero? || image.height.zero?

      image = Sizer.fit(image, width: width, height: height, scale: scale, protocol: selected, env: env)
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

    def enabled?(output:, env:)
      Inlay.config.enabled && output.tty? && env["INLAY"] != "off" && env["TERM"] != "dumb"
    end
    private_class_method :enabled?

    def next_kitty_id
      @kitty_id_lock ||= Mutex.new
      @kitty_id_lock.synchronize { @kitty_id = (@kitty_id.to_i % 2_147_483_647) + 1 }
    end
    private_class_method :next_kitty_id
  end
end
