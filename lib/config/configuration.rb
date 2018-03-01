require 'config/global_config'
require 'config/assignment_config'

$global_config_location = File.expand_path('~/.spd_global_config.toml')
$assignment_config_location = 'assignment_config.toml'

module SPD
  module Config
    class Configuration

      def initialize(global_path = $global_config_location, assignment_path = $assignment_config_location)
        @configs = []
        @configs << AssignmentConfig.load_from_file(assignment_path) if assignment_path
        @configs << GlobalConfig.load_from_file(global_path) if global_path
      end

      def method_missing(id)
        @configs.each do |config|
          if config.methods.include? id
            return config.send(id)
          end
        end

        raise "No currently loaded configs support the method `#{id}`"
      end
    end
  end
end