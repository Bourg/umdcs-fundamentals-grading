require 'thor'

require 'sanity/sanity'
require 'distribute/distributor'
require 'ingest/ingester'

require 'common/logger'

require 'config/configuration'

module SPD
  class CLI < Thor
    include SPD

    desc 'sanity', 'Create a testing setup that checks for expected files'
    option :files, {:required => true, :aliases => '-f', :type => :array}
    option :output, {:aliases => '-o', :type => :string, :default => 'sanity'}

    def sanity
      Ops::Sanity.do_sanity(options[:output], options[:files])
    end

    desc 'distribute', 'Distribute submissions to graders'
    option :do_mail, {:aliases => '-m', :type => :boolean, :default => false}
    def distribute
      Distribute::Distributor.new(load_config).do_distribute(options[:do_mail])
    end

    desc 'ingest', 'Interactively parse graded files to create uploadable CSV + redistributables'

    def ingest
      Ingest::Ingester.new(load_config).do_ingest
    end

    private

    def load_config
      Config::Configuration.new($global_config_location, $assignment_config_location)
    end
  end
end