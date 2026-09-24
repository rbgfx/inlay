# frozen_string_literal: true

require "inlay"
require "pry"

module Inlay
  module PryIntegration
    class << self
      attr_reader :original, :wrapper

      def install
        return true if Pry.config.print.equal?(@wrapper)

        @original = Pry.config.print
        @wrapper = proc do |output, value, pry_instance|
          begin
            value = Inlay.show(value) if Inlay.displayable?(value)
          rescue StandardError
            # Preserve Pry's configured printer if image rendering fails.
          end
          @original.call(output, value, pry_instance)
        end
        Pry.config.print = @wrapper
        true
      end

      def uninstall
        return false unless @wrapper && Pry.config.print.equal?(@wrapper)

        Pry.config.print = @original
        @wrapper = @original = nil
        true
      end
    end
  end
end

Inlay::PryIntegration.install
