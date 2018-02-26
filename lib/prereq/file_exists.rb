require 'prereq/base_prereq'

module SPD
  module Prereq
    class FileExists < BasePrereq
      def initialize(file)
        @file = file
      end

      def enforce
        fail("Nil file cannot possibly exist") unless @file
        fail("The file #{@file} doesn't exist") unless File.file? @file.to_s
      end
    end
  end
end