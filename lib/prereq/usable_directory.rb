require 'prereq/base_prereq'
require 'fileutils'

module SPD
  module Prereq
    class UsableDirectory < BasePrereq

      def initialize(dir)
        @dir = dir
      end

      def enforce
        fail('Cannot attempt to use a directory with an empty name') unless @dir
        @dir = @dir.to_s

        unless Dir.exist?(@dir)
          FileUtils.mkpath(@dir)
          return
        end

        print "The directory #{@dir} already exists - would you like to clear it?\n[(y)es/(n)o/(s)hare]: "
        answer = STDIN.readline.strip

        if answer =~ /^[yY](?:es)?$/
          fail('Failed to delete directory') unless FileUtils.rm_r(@dir)
          FileUtils.mkdir(@dir)
        elsif answer =~ /^[sS](?:hare)?$/
          Logger.log_warning('Sharing space with existing directory')
        else
          fail("Cannot proceed without consent to use the directory #{@dir}")
        end
      end
    end
  end
end