require 'common/logger'

module SPD
  module Prereq

    def self.enforce_many(prereqs, sift = true)
      prereqs = prereqs.to_a

      # Ensure all non-interactive prereqs first
      # This is to avoid a situation where a user is alerted of a non-interactive failure mid-interaction
      prereqs = prereqs.reject(&:interactive?) + prereqs.select(&:interactive?) if sift

      prereqs.each(&:enforce)
      nil
    end

    # This class is the superclass for all assertable prerequisites
    # Subclasses should implement an assert method
    # Subclasses should NOT implement the enforce or reason methods
    class BasePrereq
      def initialize(interactive = false)
        if self == Prereq
          raise 'Base Prereq cannot be instantiated - create a subclass or use GenericPrereq'
        end

        @interactive = interactive
      end

      def enforce
        true
      end

      def interactive?
        @interactive
      end

      def fail(reason = "Unspecified failure")
        SPD::Common::Logger.log_fatal(reason)
        exit(2) # Shouldn't happen
      end
    end
  end
end