require 'common/logger'
require 'common/result'

module SPD
  module Common
    module FileOps
      include SPD::Common

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

