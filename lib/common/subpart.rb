require 'ingest/graded_subpart'

module SPD
  module Common
    class Subpart
      attr_reader :path, :total, :weight

      # path : The regular expression of the path from the submission root
      def initialize(path, total, weight = 1)
        @path = path

        total = total.to_i
        raise "Invalid total value #{total} for subpart" unless total > 0
        @total = total

        weight = weight.to_i
        raise "Invalid total weight #{weight} for subpart" unless weight >= 0
        @weight = weight
      end

      def to_graded(students, points, filepath)
        SPD::Ingest::GradedSubpart.new(students, points * @weight, filepath)
      end
    end
  end
end