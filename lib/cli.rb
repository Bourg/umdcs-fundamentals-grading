require 'thor'

require 'prereq/base_prereq'
require 'prereq/usable_directory'
require 'prereq/generic_prereq'

require 'ops/sanity'
require 'ops/distribute'
require 'ops/ingester'

require 'prereq/generic_prereq'
require 'common/logger'
require 'config/distribution_config'
require 'config/ingest_config'

module SPD
  class CLI < Thor
    include SPD::Ops
    include SPD::Prereq

    $config_location = 'config'

    desc 'sanity', 'Create a testing setup that checks for expected files'
    option :files, {:required => true, :aliases => '-f', :type => :array}
    option :output, {:aliases => '-o', :type => :string, :default => 'sanity'}

    def sanity
      output = options[:output]
      files = options[:files]

      Prereq.enforce_many [
                              GenericPrereq.new(files) {|files|
                                "A setup must contain at least one file" if !files || files.empty? || files[0].empty?
                              }, UsableDirectory.new(output)]

      Sanity.do_sanity(output, files)
    end

    desc 'distribute', 'Distribute submissions to graders'

    def distribute
      # Load the configuration file
      config = SPD::Config::DistributionConfig.load_from_disk($config_location)
      if config.failure?
        SPD::Common::Logger.log_fatal("Could not load configuration file: #{config.value}")
      end
      config = config.value

      # Determine the directory to read from
      unless Dir.exist?(config.input_dir)
        Common.log_fatal "First argument must be the directory containing submissions"
      end

      SPD::Ops.do_distribute(config)
    end

    desc 'ingest', 'Interactively parse graded files to create uploadable CSV + redistributables'

    def ingest
      config = SPD::Config::IngestConfig.load_from_disk($config_location)
      if config.failure?
        SPD::Common::Logger.log_fatal("Could not load configuration file: #{config.value}")
      end
      config = config.value

      SPD::Ops::Ingester.new(config).do_ingest
    end
  end
end