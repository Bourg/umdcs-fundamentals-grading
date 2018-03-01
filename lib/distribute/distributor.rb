require 'fileutils'

require 'common/fileops'
require 'common/logger'

require 'prereq/base_prereq'
require 'prereq/directory_exists'
require 'prereq/usable_directory'

module SPD
  module Distribute
    class Distributor
      include SPD
      include SPD::Common

      RECORD_FILENAME = "record.csv"
      SUBMISSION_DIRNAME_REGEXP = /^(\w+)__\d+$/
      INPUT_DIR = 'submissions'
      OUTPUT_DIR = 'distributions'

      def initialize(config)
        @config = config
      end

      def do_distribute(do_mail)
        enforce_prereqs

        submissions = identify_submissions
        assignments = assign_submissions(submissions)

        packages = create_packages(assignments)

        mail_packages(packages) if do_mail

        write_record_csv(assignments)
        log_results(assignments)
      end

      private

      # enforce_prereqs : -> nil
      # Ensure that the input directory exists and the output directory is usable
      def enforce_prereqs
        Prereq.enforce_many([Prereq::DirectoryExists.new(INPUT_DIR),
                             Prereq::UsableDirectory.new(OUTPUT_DIR)])
      end

      # identify_submissions : -> Array
      # Crawl the input directory and identify ALL submissions that match the expected directory name regexp
      # The resultant Array contains hashes matching the following schema:
      #   :submitter - The directory ID of the student who made the submission
      #   :path - The absolute path to the submission root directory
      def identify_submissions
        submissions = []

        FileOps.subdirs_of(INPUT_DIR).each do |subdir|
          if subdir =~ SUBMISSION_DIRNAME_REGEXP
            submitter = $1
            submission_path = File.expand_path(File.join(INPUT_DIR, subdir))

            submissions << {submitter: submitter, path: submission_path}
          else
            Logger.log_warning "The source subdirectory #{subdir} doesn't match the regex. Omitting."
          end
        end

        submissions.sort_by {|submission| submission[:submitter]}
      end

      # assign_submissions : Array -> Hash
      # Create a mapping from graders to their submissions
      def assign_submissions(submissions)
        # Attempt to assign submissions to graders
        assignments = @config.graders.assign(submissions)
        Logger.log_fatal 'Cannot assign submissions to graders if there is no available workload' unless assignments
        assignments
      end

      # create_packages : Hash -> Hash
      # Given a hash from graders to arrays of their submissions,
      # produce a hash from graders to their absolute archive paths
      def create_packages(assignments)
        Dir.chdir(OUTPUT_DIR)

        result = assignments.map do |g, ss|
          # Stage this grader's submission files in a temporary directory
          grader_dirname = "#{g.id}_submissions_#{@config.assignment_name}"
          FileUtils.mkdir(grader_dirname)
          ss.each {|s| FileUtils.cp_r(s[:path], File.join(grader_dirname, s[:submitter]))}

          # Compress the temporary directory into a tarball
          output_filename = "#{grader_dirname}.tar.gz"
          `tar czf #{output_filename} #{grader_dirname}`

          FileUtils.rm_r(grader_dirname)

          [g, File.expand_path(output_filename)]
        end.to_h

        Dir.chdir('..')
        result
      end

      def mail_packages(packages)
        Logger.log_output("Attempting to send mail...")
        # TODO make this less crap
        mailer = Mailer.new(config.mail_sender, config.mail_subject, config.mail_body)

        config.graders.graders.select(&:archive_path).each {|grader|
          mailer.send(grader.email, grader.archive_path)
        }
      end

      def write_record_csv(assignments)
        csv_content = assignments
                          .map {|grader, ss| ss.map {|submission| "#{submission[:submitter]}, #{grader.id}\n"}}
                          .flatten
                          .reduce("", :+)
                          .strip

        # Write the record file
        File.open(File.join(OUTPUT_DIR, RECORD_FILENAME), "w") {|record_file|
          record_file.write(csv_content)
        }
      end

      def log_results(assignments)
        Logger.log_output "Done! Report:"
        Logger.log_output "\tTotal Submissions: #{assignments.values.map(&:size).reduce(0, :+)}"
        Logger.log_output "\tGrader Distributions:"
        assignments.each {|g, ss|
          Logger.log_output "\t\t#{g.id} (workload: #{g.workload}): #{ss.size}"
        }
      end
    end
  end
end