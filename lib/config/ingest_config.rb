require 'config/loadable_by_eval'

module SPD
  module Config
    class IngestConfig
      extend SPD::Config::LoadableByEval

      attr_reader :assignment_name, :input_dir, :output_csv, :subparts, :grade_regexp, :students_regexp

      def initialize(assignment_name, input_dir, output_csv, subparts, grade_regexp, students_regexp)
        @assignment_name = assignment_name.to_s
        @input_dir = input_dir.to_s
        @output_csv = output_csv.to_s
        @subparts = subparts.to_a
        @grade_regexp = Regexp.new(grade_regexp)
        @students_regexp = Regexp.new(students_regexp)
      end
    end
  end
end