require 'common/logger'

module SPD
  module Common
    module FileOps
      def self.mkdir_prompt(dir)
        if Dir.exist?(dir)
          print "The directory #{dir} already exists - would you like to overwrite? (Y/n): "
          answer = STDIN.readline.strip

          if answer =~ /^[yY](?:es)?$/
            rmd = FileUtils.rm_r(dir)

            Common.log_fatal "Couldn't remove the directory" unless rmd
          else
            Common.log_fatal "Please choose a different directory or remove the current choice manually"
          end
        end

        FileUtils.mkdir(dir)
      end
    end
  end
end

