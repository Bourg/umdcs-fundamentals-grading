module SPD
  module Common
    module Logger
      # Helpers for unified output/logging
      def self.log_output(output)
        STDOUT.puts(output)
      end

      def self.log_warning(output)
        STDOUT.puts("[WARN]: #{output}")
      end

      def self.log_error(output)
        STDERR.puts("[ERROR]: #{output}")
      end

      def self.log_fatal(output, code = 1)
        STDERR.puts("[FATAL]: #{output}")
        exit(code)
      end
    end
  end
end
