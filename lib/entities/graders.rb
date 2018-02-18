require 'common/result'
require 'entities/assignments'

module SPD
  module Entities
    class Graders
      include SPD::Common
      include SPD::Entities

      # initialize : Array<Grader>
      def initialize(graders)
        @graders = graders
      end

      # assign : Array<UngradedSubmission> -> Result
      # Success contains assignment of submissions to graders weighted by workload
      # Failure contains same results as the validate method, or additionally:
      # - [:invalid_submissions, Array<UngradedSubmission>]
      def assign(submissions)

        # Perform validation on graders and return failure if it occures
        validation_graders = validate
        return validation_graders if validation_graders.failure?

        # Perform validation on submissions, assuming they aren't null
        invalid_submissions = submissions.map(&:validate).select(&:failure?)
        return Result.failure([:invalid_submissions, invalid_submissions]) unless invalid_submissions.empty?

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

        return Result.success(Assignments.new(result))
      end

      # validate : () -> Result
      # Returns a result where failure contains one of the following:
      # - [:no_workload]
      # - [:invalid_graders, Array<Graders>]
      # Success contains nil
      def validate
        return Common::Result.failure([:no_workload]) unless @graders

        invalids = @graders.reject(&:valid?)
        return Result.failure([:invalid_graders, invalids]) unless invalids.empty?

        return Result.failure([:no_workload]) unless total_workload > 0

        return Result.success
      end

      # total_workload : () -> Float
      # Returns the total workload of all listed graders
      def total_workload
        @graders.map(&:workload).reduce(:+)
      end
    end
  end
end