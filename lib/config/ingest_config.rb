require 'config/loadable_by_eval'

module SPD
  module Config
    class IngestConfig
      extend SPD::Config::LoadableByEval

      attr_reader :course_url, :assignment_name, :input_dir, :output_csv, :output_dir, :subparts, :grade_regexp, :students_regexp

      def initialize(course_url, assignment_name,
                     input_dir, output_csv, output_dir,
                     subparts, grade_regexp, students_regexp)
        @course_url = course_url.to_s
        @assignment_name = assignment_name.to_s
        @input_dir = input_dir.to_s
        @output_csv = output_csv.to_s
        @output_dir = output_dir.to_s
        @subparts = subparts.to_a
        @grade_regexp = Regexp.new(grade_regexp)
        @students_regexp = Regexp.new(students_regexp)
      end
    end
  end
end