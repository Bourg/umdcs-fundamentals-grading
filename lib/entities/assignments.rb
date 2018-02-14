# Represents the entire set of mappings from graders to assignments
module SPD
  module Entities
    class Assignments
      def initialize(init_mapping = nil)
        init_mapping = {} unless init_mapping
        @assignments = init_mapping
      end

      def each
        @assignments.each {|g, ss| yield g, ss}
      end

      def to_record_csv
        @assignments.map {|g, ss| ss.map {|s| "#{s.student_id},#{g.id}\n"}}.flatten.reduce(:+).strip
      end
    end
  end
end