require 'prereq/base_prereq'
require 'tty-prompt'

module SPD
  module Prereq
    class GenericPrereq < BasePrereq
      def initialize(data = nil, interactive = false)
        raise 'Cannot instantiate a base Prereq without a block' unless Kernel.block_given?

        @block = Proc.new
        @data = data
        @interactive = interactive
      end

      def enforce
        if @block.arity == 0
          res = @block.call
        elsif @block.arity == 1
          res = @block.call(@data)
        else
          res = @block.call(@data, TTY::Prompt.new)
        end

        if res.is_a? String
          fail(res)
        end
      end
    end
  end
end