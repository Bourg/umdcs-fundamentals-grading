require 'fileutils'
require 'common/fileops'
require 'common/logger'
require 'entities/graded_submission'

module SPD
  module Ops
    class Ingester
      include SPD::Common
      include SPD::Entities

      def initialize(config)
        @config = config
      end

      def do_ingest
        if Dir.exist?(@config.input_dir)
          csv_lines = FileOps.subdirs_of(@config.input_dir)
                          .map {|subdir| ingest_one_interactive(subdir)}
                          .reject(&:nil?)
                          .flat_map {|graded| graded.to_csv_lines(@config.assignment_name)}

          File.open(@config.output_csv, 'w') {|output_csv|
            csv_lines.each {|csv_line| output_csv.puts(csv_line)}
          }

          Logger.log_output('Success...?')
        else
          Logger.log_fatal("Nonexistent input directory '#{@config.input_dir}'")
        end
      end

      private
      def ingest_one_interactive(submission_root)
        graded_subparts = []

        # For each subpart, find the file and extract its data
        @config.subparts.each {|subpart|
          filepath = find_file_interactive(File.join(submission_root, subpart.path), subpart)
          if filepath
            graded_subpart = extract_data_interactive(filepath, subpart)
            graded_subparts << graded_subpart if graded_subpart
          end
        }

        unless graded_subparts.empty?
          # TODO better logic for finding student IDs
          students = graded_subparts[0].students
          total_score, filepaths = *graded_subparts.inject([0, []]) {|a, graded_subpart|
            a[0] += graded_subpart.weighted_score
            a[1] << graded_subpart.filepath
            a
          }

          return GradedSubmission.new(students, total_score, filepaths)
        end

        # TODO handle all subparts invalid
        Logger.log_fatal 'Unsupported - all subparts invalid'
        return nil
      end

      def find_file_interactive(submission_root, subpart)
        path = File.join(submission_root, subpart.path)
        if Dir.exist?(submission_root)
          possibles = Dir.entries(path).select {|possible| subpart.regexp =~ possible}

          # Three possibilities:
          # - Exactly one match (yay!)
          # - More than one match (prompt for selection)
          # - No matches (prompt for manual search)
          if possibles.size == 1
            return File.join(path, possibles[0])
          elsif possibles.size > 1
            # TODO there are multiple possible matches in the directory
            Logger.log_fatal 'Unsupported - multiple possible matches for a subpart'
          else
            # TODO the file is missing in the directory
            Logger.log_fatal 'Unsupported - no matches for a subpart filename'
          end
        else
          # TODO the path to the file is missing
          Logger.log_fatal 'Unsupported - the path to a subpart is missing'
        end
      end

      def extract_data_interactive(filepath, subpart)
        contents = IO.read(filepath)

        students = nil
        points = nil

        if contents =~ @config.students_regexp
          students = [$1]
          students << $2 if $2
        else
          Logger.log_warning("Failed to extract student IDs from #{filepath}")
        end


        if contents =~ @config.grade_regexp
          points = $1.to_i
        else
          Logger.log_warning("Failed to extract scores from #{filepath}")
        end

        unless students && points
          # TODO data failed to extract
          Logger.log_fatal 'Unsupported - students and/or points failed to extract'
        end

        return subpart.to_graded(students, points, filepath)
      end
    end
  end
end