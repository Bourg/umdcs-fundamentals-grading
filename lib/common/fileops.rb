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

      def self.eval_file(path, expected = Object)
        if File.exist?(path)
          begin
            config = Kernel.eval(IO.read(path))

            if config.is_a?(expected)
              return Result.success(config)
            else
              return Result.failure([:config_type, config.class])
            end
          rescue Exception => e
            return Result.failure([:config_exception, e])
          end
        else
          return Result.failure([:config_missing, path])
        end
      end

      def self.subdirs_of(dir)
        Dir.entries(dir)
            .reject {|d| d == '.' || d == '..'}
            .map {|subdir| File.join(dir, subdir)}
            .select {|path| Dir.exist?(path)}
      end
    end
  end
end

