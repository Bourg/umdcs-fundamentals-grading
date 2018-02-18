require 'common/result'

module SPD
  module Entities
    class UngradedSubmission
      include SPD::Common
      attr_accessor :student_id, :path

      def initialize(student_id, path)
        @student_id = student_id.to_s.freeze
        @path = path.to_s.freeze
      end

      # validate : () -> Result
      # On success, returns no explicit value
      # On failure, returns one of the following values:
      # - :empty_id
      # - :invalid_path
      def validate
        return Result.failure(:empty_id) unless @student_id && !@student_id.empty?
        return Result.failure(:invalid_path) unless Dir.exist? @path
        return Result.success
      end
    end
  end
end