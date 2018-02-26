require 'thor'

require 'ops/sanity'
require 'ops/distribute'
require 'ops/ingester'

require 'common/logger'

require 'config/global_config'
require 'config/ingest_config'

module SPD
  class CLI < Thor
    include SPD::Ops

    $config_location = 'config'

    desc 'sanity', 'Create a testing setup that checks for expected files'
    option :files, {:required => true, :aliases => '-f', :type => :array}
    option :output, {:aliases => '-o', :type => :string, :default => 'sanity'}

    def sanity
      Sanity.do_sanity(options[:output], options[:files])
    end

    desc 'distribute', 'Distribute submissions to graders'

    def distribute(config_path)
      config = SPD::Config::GlobalConfig.load_from_file(config_path)
      SPD::Ops::Distribute.do_distribute(config)
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