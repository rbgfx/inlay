# frozen_string_literal: true

require "inlay"
require "irb"
require "irb/inspector"

module Inlay
  module IRBIntegration
    class << self
      attr_reader :original, :wrapper

      def install
        mode = IRB.conf[:INSPECT_MODE]
        selected = mode.is_a?(IRB::Inspector) ? mode : IRB::Inspector::INSPECTORS[mode] || IRB::Inspector::INSPECTORS[mode.to_s] || IRB::Inspector::INSPECTORS[:p]
        return false unless selected

        unless mode.equal?(@wrapper)
          @original = selected
          @original.init
        end
        @protocol = TerminalOutput.protocol
        @wrapper = IRB::Inspector.new(proc do |value, output, colorize: true|
          begin
            if Inlay.displayable?(value)
              output << Inlay.show(value, protocol: @protocol)
            else
              @original.inspect_value(value, output, colorize: colorize)
            end
          rescue StandardError
            @original.inspect_value(value, output, colorize: colorize)
          end
        end)
        IRB.conf[:INSPECT_MODE] = @wrapper
        context = IRB.CurrentContext if IRB.respond_to?(:CurrentContext)
        context.inspect_mode = @wrapper if context&.respond_to?(:inspect_mode=)
        true
      end

      def uninstall
        return false unless @wrapper && IRB.conf[:INSPECT_MODE].equal?(@wrapper)

        IRB.conf[:INSPECT_MODE] = @original
        context = IRB.CurrentContext if IRB.respond_to?(:CurrentContext)
        context.inspect_mode = @original if context&.respond_to?(:inspect_mode=)
        @wrapper = @original = @protocol = nil
        true
      end
    end
  end
end

Inlay::IRBIntegration.install
