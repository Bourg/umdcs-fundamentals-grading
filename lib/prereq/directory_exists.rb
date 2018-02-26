require 'prereq/base_prereq'

module SPD
  module Prereq
    class DirectoryExists < BasePrereq
      def initialize(dir)
        @dir = dir
      end

      def enforce
        fail("Nil directory cannot possibly exist") unless @dir
        fail("The directory #{@dir} doesn't exist") unless Dir.exist? @dir.to_s
      end
    end
  end
end