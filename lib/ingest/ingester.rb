require 'fileutils'
require 'digest'
require 'csv'
require 'date'

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
      SUBMISSION_DATA_CSV = 'submission_data.csv'

      def initialize(config)
        @config = config
        @digester = Digest::MD5.new
      end

      def do_ingest
        enforce_prereqs

        graded_submissions = FileOps.subdirs_of(INPUT_DIR)
                                 .map {|subdir| ingest_one_interactive(subdir, File.join(INPUT_DIR, subdir))}
                                 .reject(&:nil?)

        deduplicate_submissions(graded_submissions)

        csv_lines = graded_submissions.flat_map {|graded| graded.to_csv_lines(@config.course_url,
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
      def ingest_one_interactive(submitter, submission_root)
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

        return GradedSubmission.new(submitter, graded_subparts)
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

      # deduplicate_submissions : Array -> Array
      # Given an array of GradedSubmissions, cross-reference it with the submission data CSV to remove duplicates
      def deduplicate_submissions(submissions)
        unless File.file? SUBMISSION_DATA_CSV
          Logger.log_warning("There is no submission data CSV at path #{SUBMISSION_DATA_CSV} - cannot deduplicate")
          Logger.log_warning("You can get the CSV under Utilities -> Print grades for ALL submissions in CSV format")
          return submissions
        end

        begin
          Logger.log_output('Reading data from submission data CSV...')
          timestamps = CSV.read(SUBMISSION_DATA_CSV)[1..-1].map {|entry| [entry[0], entry[2].to_i]}.to_h
        rescue
          Logger.log_warning("Something went wrong while deduplicating submissions")
          Logger.log_warning("Make sure #{SUBMISSION_DATA_CSV} is a valid CSV file")
          return submissions
        end

        # Map each grouping of partnered submissions to the latest timestamped submission
        # TODO this assumes that the latest submission had the names of both partners
        # TODO a better solution may be to manually set the partners in this submission to match an aggregate
        group_partner_submissions(submissions).map do |grouping|
          sorted_submissions = grouping.sort_by {|s| -timestamps[s.submitter]}
          real_submission = sorted_submissions[0]

          if grouping.size != 1
            Logger.log_warning("#{grouping.size} submissions found for #{real_submission.students.join(", ")} (keeping most recent):")

            sorted_submissions.each  do |submission|
              formatted_timestamp = Time.at(timestamps[submission.submitter] / 1000.0).strftime("on %B %e at %H:%M")
              Logger.log_warning("\t#{submission.submitter} #{formatted_timestamp}")
            end
          end

          real_submission
        end
      end

      # group_partner_submissions : Array -> Array
      # Given an array of GradedSubmissions, group them together by partnerships
      def group_partner_submissions(submissions)
        # Mapping from every partner (not just submitters) to their submissions
        groupings = {}

        # For each submission, unify existing submissions around these partners
        submissions.each do |submission|
          common_submissions = submission.students.inject([submission]) do |common_submissions, student|
            common_submissions += groupings[student] if groupings[student]
            common_submissions
          end

          submission.students.each {|student| groupings[student] = common_submissions}
        end

        groupings.values.uniq.map(&:uniq)
      end
    end
  end
end