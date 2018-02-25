require 'prereq/base_prereq'

module SPD
  module Prereq
    class GenericPrereq < BasePrereq
      def initialize(data, interactive = false)
        raise 'Cannot instantiate a base Prereq without a block' unless Kernel.block_given?

        @block = Proc.new
        @data = data
        @interactive = interactive
      end

      def enforce
        res = @block.call(@data)

        if res.is_a? String
          fail(res)
        end
      end
    end
  end
end