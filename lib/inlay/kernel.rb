# frozen_string_literal: true

require "inlay"

module Kernel
  private

  def inlay(object, **options)
    Inlay.show(object, **options)
  end
end
