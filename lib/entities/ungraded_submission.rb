require 'common/result'

module SPD
  module Entities
    class UngradedSubmission
      attr_accessor :student_id, :path

      def initialize(student_id, path)
        @student_id = student_id
        @path = path
      end

      # validate : () -> Result
      # On success, returns no explicit value
      # On failure, returns one of the following values:
      # - :empty_id
      # - :invalid_path
      def validate
        return Common::Result.failure(:empty_id) unless @student_id && !@student_id.empty?
        return Common::Result.failure(:invalid_path) unless Dir.exist? @path
        return Common::Result.success
      end
    end
  end
end