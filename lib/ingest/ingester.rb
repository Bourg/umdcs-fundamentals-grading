require 'fileutils'
require 'digest'
require 'common/fileops'
require 'common/logger'
require 'ingest/graded_submission'
require 'prereq/usable_directory'
require 'prereq/directory_exists'
require 'prereq/base_prereq'

module SPD
  module Ops
    class Ingester
      include SPD::Common
      include SPD::Entities
      include SPD::Prereq

      $input_dir = 'graded'
      $output_dir = 'return'

      def initialize(global_config, local_config)
        @global_config = global_config
        @local_config = local_config
        @digester = Digest::MD5.new
      end

      def do_ingest
        Prereq.enforce_many([
                                UsableDirectory.new($output_dir),
                                DirectoryExists.new($input_dir)])


        csv_lines = FileOps.subdirs_of($input_dir)
                        .map {|subdir| ingest_one_interactive(subdir)}
                        .reject(&:nil?)
                        .flat_map {|graded| graded.to_csv_lines(@global_config.course_url,
                                                                @local_config.assignment_name)}

        File.open(@local_config.output_csv, 'w') {|output_csv|
          csv_lines.each {|csv_line| output_csv.puts(csv_line)}
        }

        Logger.log_output('Success!')
      end

      private
      def ingest_one_interactive(submission_root)
        graded_subparts = []

        # For each subpart, find the file and extract its data
        @local_config.subparts.each {|subpart|
          filepath = find_file_interactive(submission_root, subpart.path)
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

      def find_file_interactive(submission_root, path)
        path = File.join(submission_root, path)

        if File.file?(path)
          return path
        else
          # TODO the file is missing in the directory
          Logger.log_fatal "Unsupported - no matches for a subpart filename in root #{submission_root}"
        end
    end

    def extract_data_interactive(filepath, subpart)
      contents = IO.read(filepath)

      students = nil
      points = nil

      if contents =~ @local_config.students_regexp
        students = [$1]
        students << $2 if $2
      else
        Logger.log_warning("Failed to extract student IDs from #{filepath} using regexp /#{@local_config.students_regexp.source}/")
      end


      if contents =~ @local_config.grade_regexp
        points = $1.to_i
      else
        Logger.log_warning("Failed to extract scores from #{filepath} using regexp /#{@local_config.grade_regexp.source}/")
      end

      unless students && points
        # TODO data failed to extract
        Logger.log_fatal 'Unsupported - students and/or points failed to extract'
      end

      output_filepath = create_returnable_file(filepath)

      return subpart.to_graded(students, points, output_filepath)
    end

    def create_returnable_file(filepath)
      unless File.exist?(filepath)
        Logger.log_fatal("There is no file to pack at #{filepath}")
      end

      @digester.reset
      @digester << IO.read(filepath)
      output_filepath = File.join($output_dir, @digester.hexdigest + File.extname(filepath))
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