require 'uri'

module SPD
  module Entities
    class GradedSubmission
      attr_reader :students, :total_score, :filepaths

      def initialize(students, total_score, filepaths)
        @students = students.to_a.clone.freeze
        @total_score = total_score.to_i
        @filepaths = filepaths.to_a
      end

      def to_csv_lines(course_url, assignment_name)
        webpage_paths = @filepaths.map {|p|
          URI.join(course_url, File.basename(p)).to_s
        }.join('\n')

        @students.map {|student|

          "#{student},#{assignment_name},#{@total_score},#{webpage_paths}"
        }
      end
    end
  end
end