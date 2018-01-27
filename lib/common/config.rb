require "common/logger"
require "common/result"
require "entities"

$SPDRC_EVAR = "SPDRC"

module Common

  class Config
    attr_reader :graders

    # initialize : Hash<String, Float> ->
    # Creates a new Config object based on a mapping of grader IDs to grading weights
    def initialize(graders = nil)
      graders = {} if graders == nil
      @graders = Entities::Graders.new(
        graders.map{|id, w|
          Entities::Grader.new(id, w)
        }.shuffle
      )

      yield self if block_given?
    end

    # load_from_disk : -> Config
    # Loads the config file from disk based on the SPDRC environment variable.
    # On success, returns the Config object defined at that path
    # On failure, returns one of the following:
    # - [:spdrc_unset] when the environment variable is not set
    # - [:spdrc_missing, <path>] when the path set does not exist
    # - [:spdrc_exception, <exception>] when evaluation raises an exception
    # - [:spdrc_type, <Class>] when evaluation doesn't yield a Config object
    def self.load_from_disk
      if ENV[$SPDRC_EVAR]
        spdrc_path = File.expand_path(ENV[$SPDRC_EVAR])

        if File.exist?(spdrc_path)
          begin
            config = Kernel.eval(IO.read(spdrc_path))

            if config.class == Config
              return Common::Result.success(config)
            else
              return Common::Result.failure([:spdrc_type, config.class])
            end
          rescue Exception => e
            return Common::Result.failure([:spdrc_exception, e])
          end
        else
          return Common::Result.failure([:spdrc_missing, spdrc_path])
        end
      else
        return Common::Result.failure([:spdrc_unset])
      end
    end
  end
end
