require 'common/result'
require 'entities/grader'
require 'entities/graders'
require 'config/loadable_by_eval'

module SPD
  module Config
    class DistributionConfig
      include SPD::Common
      include SPD::Entities
      extend SPD::Config::LoadableByEval

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
        @input_dir = input_dir
        @output_dir = output_dir

        options = {} unless options
        @options = options.clone.freeze
      end

      def submission_dirname_regex
        /^(\w+)__\d+$/
      end
    end
  end
end