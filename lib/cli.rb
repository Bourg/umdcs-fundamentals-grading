require 'thor'

require 'ops/sanity'
require 'ops/distribute'
require 'ops/ingester'

require 'common/logger'

require 'config/global_config'
require 'config/assignment_config'

module SPD
  class CLI < Thor
    include SPD

    $global_config_location = File.expand_path('~/.spd_global_config.toml')
    $assignment_config_location = 'assignment_config.toml'

    desc 'sanity', 'Create a testing setup that checks for expected files'
    option :files, {:required => true, :aliases => '-f', :type => :array}
    option :output, {:aliases => '-o', :type => :string, :default => 'sanity'}

    def sanity
      Ops::Sanity.do_sanity(options[:output], options[:files])
    end

    desc 'distribute', 'Distribute submissions to graders'

    def distribute
      Ops::Distribute.do_distribute(load_global_config)
    end

    desc 'ingest', 'Interactively parse graded files to create uploadable CSV + redistributables'

    def ingest
      Ops::Ingester.new(load_global_config, load_assignment_config).do_ingest
    end

    private

    def load_global_config
      Config::GlobalConfig.load_from_file($global_config_location)
    end

    def load_assignment_config
      Config::AssignmentConfig.load_from_file($assignment_config_location)
    end
  end
end