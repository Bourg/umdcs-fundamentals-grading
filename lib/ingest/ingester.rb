require 'fileutils'
require 'digest'

require 'common/fileops'
require 'common/logger'

require 'prereq/usable_directory'
require 'prereq/directory_exists'
require 'prereq/base_prereq'

require 'ingest/graded_submission'

module SPD
  module Ingest
    class Ingester
      include SPD::Common
      include SPD::Prereq

      INPUT_DIR = 'graded'
      OUTPUT_DIR = 'return'

      def initialize(config)
        @config = config
        @digester = Digest::MD5.new
      end

      def do_ingest
        enforce_prereqs

        csv_lines = FileOps.subdirs_of(INPUT_DIR)
                        .map {|subdir| ingest_one_interactive(File.join(INPUT_DIR, subdir))}
                        .reject(&:nil?)
                        .flat_map {|graded| graded.to_csv_lines(@config.course_url,
                                                                @config.assignment_name)}

        File.open(@config.output_csv, 'w') {|output_csv|
          csv_lines.each {|csv_line| output_csv.puts(csv_line)}
        }

        Logger.log_output('Success!')
      end

      private

      def enforce_prereqs
        Prereq.enforce_many([
                                UsableDirectory.new(OUTPUT_DIR),
                                DirectoryExists.new(INPUT_DIR)])
      end

      # ingest_one_interactive : String -> GradedSubmission
      # Performs the interactive ingest process rooted in the requested directory
      # This involves locating the files and parsing grades/comments
      # If the whole submission is well-formed, there should be no interactive steps
      def ingest_one_interactive(submission_root)
        # For each subpart, attempt to locate the file and extract its data
        graded_subparts = @config.subparts.flat_map do |subpart|
          filepath = find_file_interactive(submission_root, subpart.path)
          if filepath
            graded_subpart = extract_data_interactive(filepath, subpart)
            graded_subpart ? [graded_subpart] : []
          else
            []
          end
        end

        # If ALL of the subparts were invalid, that means no student ID could be extracted
        if graded_subparts.empty?
          # TODO handle all subparts invalid
          Logger.log_fatal 'Unsupported - all subparts invalid'
          return nil
        end

        # TODO better logic for finding student IDs
        students = graded_subparts[0].students
        total_score, filepaths = *graded_subparts.inject([0, []]) {|a, graded_subpart|
          a[0] += graded_subpart.weighted_score
          a[1] << graded_subpart.filepath
          a
        }

        return GradedSubmission.new(students, total_score, filepaths)
      end

      # find_file_interactive : String String -> String
      # Given the root of a submission and the expected path to a subpart file, attempt to find the file.
      # If the file isn't in the obvious location, an interactive prompt will guide in finding the file.
      def find_file_interactive(submission_root, path)
        path = File.join(submission_root, path)

        if File.file?(path)
          return path
        else
          # TODO the file is missing in the directory
          Logger.log_fatal "Unsupported - no subpart file found at #{path}"
        end
      end

      # extract_data_interactive : String Subpart -> GradedSubpart
      # Given the already-verified path to a subpart file, parse its contents.
      # This data is used to transform a Subpart into a GradedSubpart containing student names and grades.
      def extract_data_interactive(filepath, subpart)
        contents = IO.read(filepath)

        students = nil
        points = nil

        if contents =~ @config.students_regexp
          students = [$1]
          students << $2 if $2
        else
          Logger.log_warning("Failed to extract student IDs from #{filepath} using regexp /#{@config.students_regexp.source}/")
        end


        if contents =~ @config.grade_regexp
          points = $1.to_i
        else
          Logger.log_warning("Failed to extract scores from #{filepath} using regexp /#{@config.grade_regexp.source}/")
        end

        unless students && points
          # TODO data failed to extract
          Logger.log_fatal 'Unsupported - students and/or points failed to extract'
        end

        output_filepath = create_returnable_file(filepath)

        return subpart.to_graded(students, points, output_filepath)
      end

      # create_returnable_file : String -> String
      # Given the path to a subpart file, create a new output file with an obscured name and return its path
      def create_returnable_file(filepath)
        unless File.file?(filepath)
          Logger.log_fatal("There is no file to pack at #{filepath}")
        end

        @digester.reset
        @digester << IO.read(filepath)
        output_filepath = File.join(OUTPUT_DIR, @digester.hexdigest + File.extname(filepath))
        @digester.reset

        if File.exist?(output_filepath)
          Logger.log_fatal("Output file collision! Input '#{filepath}' hash collided with output '#{output_filepath}'!")
        end

        FileUtils.cp(filepath, output_filepath)
        return output_filepath
      end
    end
  end
end