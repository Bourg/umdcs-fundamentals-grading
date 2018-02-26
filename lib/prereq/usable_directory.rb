require 'prereq/base_prereq'
require 'fileutils'
require 'tty-prompt'

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

        case TTY::Prompt.new.expand("The directory #{@dir} already exists - clear it?") do |q|
          q.choice key: 'n', name: 'No', value: :no
          q.choice key: 'y', name: 'Yes', value: :yes
          q.choice key: 's', name: 'Share (use the directory without clearning)', value: :share
        end
          when :yes
            fail('Failed to delete directory') unless FileUtils.rm_r(@dir)
            FileUtils.mkdir(@dir)
          when :no
            fail("Cannot proceed without consent to use the directory #{@dir}")
          when :share
            Logger.log_warning('Sharing space with existing directory')
        end
      end
    end
  end
end