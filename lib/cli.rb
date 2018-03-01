require 'thor'

require 'ops/sanity'
require 'ops/distribute'
require 'ops/ingester'

require 'common/logger'

require 'config/global_config'
require 'config/assignment_config'
require 'config/ingest_config'

module SPD
  class CLI < Thor
    include SPD::Ops

    $global_config_location = 'global_config'
    $assignment_config_location = 'assignment_config'

    desc 'sanity', 'Create a testing setup that checks for expected files'
    option :files, {:required => true, :aliases => '-f', :type => :array}
    option :output, {:aliases => '-o', :type => :string, :default => 'sanity'}

    def sanity
      Sanity.do_sanity(options[:output], options[:files])
    end

    desc 'distribute', 'Distribute submissions to graders'

    def distribute
      config = SPD::Config::GlobalConfig.load_from_file($global_config_location)
      SPD::Ops::Distribute.do_distribute(config)
    end

    desc 'ingest', 'Interactively parse graded files to create uploadable CSV + redistributables'

    def ingest
      global_config = SPD::Config::GlobalConfig.load_from_file($global_config_location)
      local_config = SPD::Config::AssignmentConfig.load_from_file($assignment_config_location)

      SPD::Ops::Ingester.new(global_config, local_config).do_ingest
    end
  end
end