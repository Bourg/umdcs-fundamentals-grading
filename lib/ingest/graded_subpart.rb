module SPD
  module Ingest
    class GradedSubpart
      attr_reader :weighted_score, :students, :filepath

      def initialize(students, weighted_score, filepath)
        @weighted_score = weighted_score
        @students = students
        @filepath = filepath
      end
    end
  end
end