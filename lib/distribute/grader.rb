module SPD
  module Entities
    class Grader
      attr_reader :id, :email, :workload

      # Create a new grader by email and workload modifier
      def initialize(id, workload, active, email = nil)
        @id = id.to_s
        @email = email.to_s
        @workload = workload.to_f
        @active = !!active
      end

      def active?
        @workload > 0 && @active
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
