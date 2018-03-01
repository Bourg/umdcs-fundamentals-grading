module SPD
  module Entities
    class Graders
      include SPD::Common
      include SPD::Entities

      attr_reader :graders

      # initialize : Array<Grader>
      def initialize(graders)
        @graders = graders.to_a.clone.freeze
      end

      def by_id(id)
        @graders.each{|grader|
          return grader if grader.id == id
        }

        return nil
      end

      # assign : Array -> Hash or Nil
      # Creates a mapping from each Grader to an Array (subset of input) in accordance with workloads
      # Returns nil if the total workload isn't positive
      def assign(submissions)
        return nil if total_workload <= 0

        # At this point, assume the graders and submissions are both valid, i.e.:
        # - Non-zero number of identified graders with a net positive workload
        # - Some number of submissions with known owners and file locations

        # Determine which graders are active, sorted from greatest to least workload
        active_graders = @graders.select(&:active?).sort_by(&:workload).reverse

        # Compute how many submissions should each grader do as a minimum
        grader_counts = active_graders
                            .map {|g| [g, g.min_submissions(total_workload, submissions.size)]}
                            .to_h

        unassigned_submissions = submissions.size - grader_counts.values.reduce(:+)

        raise 'BAD MATH, NEGATIVE UNASSIGNED SUBMISSIONS' if unassigned_submissions < 0

        # So long as there are submissions needing a grader, spread it around
        # In theory, this loop should never touch a grader more than once
        next_responsible_grader = 0
        while unassigned_submissions > 0
          grader_counts[active_graders[next_responsible_grader]] += 1

          next_responsible_grader += 1
          next_responsible_grader %= active_graders.size
          unassigned_submissions -= 1
        end

        # Translate the number of submissions to grade into concrete submissions
        result = {}
        remaining_submissions = submissions.dup
        grader_counts.each {|g, n|
          if n > 0
            result[g] = remaining_submissions.take(n)
            remaining_submissions = remaining_submissions.drop(n)
          end
        }

        result
      end

      # total_workload : () -> Float
      # Returns the total workload of all listed graders
      def total_workload
        @graders.map(&:workload).reduce(:+)
      end
    end
  end
end