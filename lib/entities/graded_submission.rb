module SPD
  module Entities
    class GradedSubmission
      attr_reader :students, :total_score, :filepaths

      def initialize(students, total_score, filepaths)
        @students = students.to_a.clone.freeze
        @total_score = total_score.to_i
        @filepaths = filepaths.to_a
      end

      def to_csv_lines(assignment_name)
        @students.map{|student|
          "#{student},#{assignment_name},#{@total_score},"
        }
      end
    end
  end
end