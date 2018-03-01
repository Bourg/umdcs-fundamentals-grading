require 'toml-rb'
require 'tty-prompt'

module SPD
  module Config
    class BaseConfig
      private_class_method :new

      def initialize(path)
        # Attempt to load
        if File.file?(path)
          config = TomlRB.load_file(path)
        else
          config = {}
        end

        @p = TTY::Prompt.new

        if Kernel.block_given?
          Proc.new.call(config)
        end

        @config = config
        File.write(path, TomlRB.dump(@config))
      end

      def config
        @config
      end

      def descend(hash, key)
        sub = hash.fetch(key, {})
        sub = {} unless sub.is_a? Hash

        yield sub
        hash[key] = sub
      end

      def descend_value(hash, key)
        hash[key] = yield hash[key]
      end

      def self.load_from_file(path)
        new(path)
      end
    end
  end
end