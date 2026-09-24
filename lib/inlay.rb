# frozen_string_literal: true

require "tessel"
require "termvas"
require "pathname"
require_relative "inlay/version"
require_relative "inlay/config"
require_relative "inlay/adapters"
require_relative "inlay/normalizer"
require_relative "inlay/sizer"
require_relative "inlay/summary"
require_relative "inlay/terminal_output"

module Inlay
  class Error < StandardError; end

  class << self
    def config
      @config ||= Config.new
    end

    def register(klass, &adapter)
      raise ArgumentError, "an adapter block is required" unless adapter

      Adapters.register(klass, adapter)
    end

    def normalize(object, allow_path: false)
      Normalizer.call(object, allow_path: allow_path)
    end

    def displayable?(object)
      normalized = normalize(object)
      !!(normalized.image || normalized.svg || normalized.png || normalized.frames)
    rescue StandardError
      false
    end

    def protocol
      TerminalOutput.protocol
    end

    def irb_install!
      require_relative "inlay/irb"
      IRBIntegration.install
    end

    def irb_uninstall!
      IRBIntegration.uninstall if defined?(IRBIntegration)
    end

    def show(object, width: nil, height: nil, scale: :auto, protocol: nil)
      normalized = normalize(object, allow_path: true)
      image = Normalizer.terminal_image(normalized)
      normalized.image ||= image
      summary = Summary.call(object, normalized)
      return summary unless image && TerminalOutput.write(image, width: width, height: height, scale: scale, protocol: protocol)

      summary
    end
  end
end
