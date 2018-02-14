module SPD
  module Entities
    class Grader
      attr_reader :id, :workload

      # Create a new grader by email and workload modifier
      # id may be an email or any other piece of identifying information
      def initialize(id, workload = 1)
        # Extract the username from an email address if an email is given
        if id =~ /^(.+)@.+\..+$/
          @id = $1
        else
          @id = id
        end

        @workload = workload.to_f
      end

      def valid?
        id && !id.empty? && workload && workload >= 0
      end

      def active?
        workload > 0
      end

      # min_submissions : Float Integer -> Integer
      # Given the workload cost of a submission, compute the minimum number of
      # submissions that should be assigned to this grader
      def min_submissions(total_workload, num_submissions)
        (num_submissions * @workload / total_workload).to_i
      end
    end
  end
end
