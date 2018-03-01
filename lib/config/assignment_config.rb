require 'config/base_config'
require 'ingest/subpart'

module SPD
  module Config
    class AssignmentConfig < BaseConfig
      attr_reader :assignment_name, :subparts, :students_regexp, :grade_regexp

      def initialize(path)
        super(path) do |config|
          validate_assignment config
          validate_regexps config
        end

        @assignment_name = @config["assignment"]["name"]
        @subparts = @config["assignment"]["subparts"].map do |_, data|
          SPD::Entities::Subpart.new(data['path'], data['points'], data['weight'])
        end
        @students_regexp = Regexp.new(@config["regexp"]["students"])
        @grade_regexp = Regexp.new(@config["regexp"]["grade"])
      end

      def output_csv
        "#{@name}.csv"
      end

      private

      def validate_assignment(config)
        descend(config, 'assignment') do |assignment_section|
          descend_value(assignment_section, 'name') do |name|
            unless name
              name = @p.ask("What is the short name of this assignment?", required: true)
            end

            name
          end

          descend(assignment_section, 'subparts') do |subparts|
            # TODO rework to use same code for validation/creation like with graders
            if subparts.empty?

              while @p.yes?("Would you like to define another subpart to ingest? (currently #{subparts.size})")
                path = @p.ask("What is the path to this file? (relative to submission root)", required: true)

                points = @p.ask("How many points is this part worth?",
                                required: true, convert: :int) do |q|
                  q.validate {|v| v.to_i > 0}
                end

                weight = @p.ask("What is the weight of this part?",
                                default: '1', convert: :int) do |q|
                  q.validate {|v| v.to_f > 0}
                end

                part_number = subparts.size + 1
                while subparts.has_key? part_number.to_s
                  part_number += 1
                end

                subparts[part_number.to_s] = {'path' => path, 'points' => points, 'weight' => weight}
              end
            end
          end
        end
      end

      def validate_regexps(config)
        descend(config, 'regexp') do |regexp_section|
          descend_value(regexp_section, 'students') do |students_regexp|
            unless students_regexp
              students_regexp =
                  @p.select("Which regexp style would you like to use to capture students?",
                            {'Racket' => /^;;>\s*(\w+)(?:\s*(\w+))?\s*$/.source,
                             'Java' => /^\/\/>\s*(\w+)(?:\s*(\w+))?\s*$/.source,
                             'Custom' => Proc.new {@p.ask("Enter a regexp that captures students:",
                                                          required: true)}})
            end

            students_regexp
          end

          descend_value(regexp_section, 'grade') do |grade_regexp|
            unless grade_regexp
              grade_regexp = @p.select("Which regexp style would you like to use to capture grades?",
                                 {'Racket' => /^;;>\s*([0-9]+)(?:\s*\/[0-9]+)?/.source,
                                  'Java' => /^\/\/>\s*([0-9]+)(?:\s*\/[0-9]+)?/.source,
                                  'Custom' => Proc.new {@p.ask("Enter a regexp that captures grades:",
                                                               required: true)}})
            end

            grade_regexp
          end
        end
      end
    end
  end
end