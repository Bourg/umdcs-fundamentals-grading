require "common/result"
require "entities/grader"
require "entities/graders"

module SPD
  module Config
    class DistributionConfig
      include SPD::Common
      include SPD::Entities

      attr_reader :graders, :input_dir, :output_dir, :options

      # Creates a new Config object based on a mapping of grader IDs to grading weights
      #   graders : Either a Hash from email to grading weight, or a Graders object
      #   input_dir : the directory to probe for submissions
      #   output_dir : the directory to output submissions
      #   options : additional options for the distribution process
      def initialize(input_dir, output_dir, graders = nil, options = nil)
        graders = {} unless graders

        if graders.instance_of? Hash
          @graders = Graders.new(
              graders.map {|id, w|
                Grader.new(id, w)
              }.shuffle
          ).freeze
        else
          @graders = graders.clone.freeze
        end
        @input_dir = input_dir.clone.freeze
        @output_dir = output_dir.clone.freeze

        options = {} unless options
        @options = options.clone.freeze
      end

      # TODO make this configurable
      def submission_dirname_regex
        /^(\w+)__\d+$/
      end

      # load_from_disk : -> Config
      # Loads the config file from disk at the requested path
      # On success, returns the Config object defined at that path
      # On failure, returns one of the following:
      # - [:config_missing, <path>] when the path set does not exist
      # - [:config_exception, <exception>] when loading raises an exception
      # - [:config_type, <Class>] when evaluation doesn't yield a Config object
      def self.load_from_disk(path)
        if File.exist?(path)
          begin
            config = Kernel.eval(IO.read(path))

            if config.class == DistributionConfig
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
    end
  end
end