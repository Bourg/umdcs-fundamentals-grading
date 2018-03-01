require 'uri'
require 'common/logger'

module SPD
  module Ingest
    class GradedSubmission
      include SPD::Common

      attr_reader :submitter, :partner, :students, :total_score, :filepaths

      def initialize(submitter, graded_subparts)

        # TODO better logic for finding student IDs
        # Current logic: If there is one student, they must match the submitter name
        #                If there are two students, one must match the submitter name
        students = graded_subparts[0].students
        if students.size == 1
          unless students[0] == submitter
            Logger.log_fatal("Submission for #{submitter} doesn't contain the name of the submitter, instead contains #{students.join(", ")}")
          end

          partner = nil
        elsif students.size == 2
          if students[0] == submitter
            partner = students[1]
          elsif students[1] == submitter
            partner = students[0]
          else
            Logger.log_fatal("Submission for #{submitter} doesn't contain the name of the submitter")
          end
        else
          Logger.log_fatal("Invalid student array size for #{submitter}")
        end

        total_score, filepaths = *graded_subparts.inject([0, []]) {|a, graded_subpart|
          a[0] += graded_subpart.weighted_score
          a[1] << graded_subpart.filepath
          a
        }


        @submitter = submitter
        @partner = partner
        @students = partner ? [submitter, partner] : [submitter]
        @total_score = total_score
        @filepaths = filepaths
      end

      def to_csv_lines(course_url, assignment_name)
        webpage_paths = @filepaths.map {|p|
          #TODO THIS BREAKS ON WINDOWS BECAUSE \\
          File.join(course_url, assignment_name, File.basename(p)).to_s
        }.join('\n')

        @students.map {|student|

          "#{student},#{assignment_name},#{@total_score},\"#{webpage_paths}\""
        }
      end
    end
  end
end