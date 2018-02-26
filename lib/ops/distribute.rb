require 'fileutils'

require 'common/fileops'
require 'common/logger'
require 'entities/ungraded_submission'
require 'common/mailer'

require 'prereq/directory_exists'
require 'prereq/usable_directory'

$RECORD_FILENAME = "record.csv"

module SPD
  module Ops
    class Distribute
      include SPD::Common
      include SPD::Entities
      include SPD::Prereq

      # Perform the distribution task
      # Assume that the config has been validated
      def self.do_distribute(config)
        $submission_dirname_regexp = /^(\w+)__\d+$/
        $input_dir = 'submissions'
        $output_dir = 'distributions'


        Prereq.enforce_many([DirectoryExists.new($input_dir), UsableDirectory.new($output_dir)])

        # Identify submissions, construct corresponding entities and validate
        submissions = []
        Dir.foreach($input_dir) {|subdir|
          unless subdir == '.' || subdir == '..'
            # If the subdirectory matches the expected format
            if subdir =~ $submission_dirname_regexp
              # Extract the submitter's UID
              submitter_id = $1
              submission_dir = File.join($input_dir, subdir)

              # Construct and validate a submission object
              submission = UngradedSubmission.new(submitter_id, submission_dir)
              submission_validation = submission.validate

              # If the submission validates, keep it. Otherwise, log a warning.
              if submission_validation.success?
                submissions << submission
              else
                Logger.log_warning "Found an invalid submission by #{submitter_id} at #{submission_dir}: #{submission_validation.value.inspect}. Omitting."
              end
            else
              Logger.log_warning "The source subdirectory #{subdir} doesn't match the regex. Omitting."
            end
          end
        }
        # Sort the submissions since we're all used to getting contiguous names
        submissions.sort_by!(&:student_id)

        # Attempt to assign submissions to graders
        assignments_result = config.graders.assign(submissions)
        if assignments_result.failure?
          Logger.log_fatal "Failed to assign submissions to graders: #{assignments_result.value.inspect}"
        end
        assignments = assignments_result.value

        # Construct file structure for grading packages
        assignments.each {|g, ss|
          grader_dir = File.join($output_dir, g.id)
          FileUtils.mkdir(grader_dir)

          ss.each {|s|
            FileUtils.cp_r(s.path, File.join(grader_dir, s.student_id))
          }
        }

        # Write the record file
        File.open(File.join($output_dir, $RECORD_FILENAME), "w") {|record_file|
          record_file.write(assignments.to_record_csv)
        }

        # Archive each grader's folder into a tarball and clean up
        Dir.chdir($output_dir)
        Dir.foreach('.') {|subdir|
          unless subdir == "." || subdir == ".." || !File.directory?(subdir)
            output_filename = "#{subdir}-submissions.tar.gz"
            `tar czf #{output_filename} #{subdir}`

            grader = config.graders.by_id(subdir)
            if grader
              grader.archive_path = File.join($output_dir, output_filename)
            else
              Logger.log_fatal("No Grader object match for subdir #{subdir} - this should not happen!")
            end

            FileUtils.rm_r(subdir)
          end
        }
        Dir.chdir('..')

        <<-MAIL_LOGIC
        # Send mail if it was requested
        if config.send_mail?
          Logger.log_output("Attempting to send mail...")
          # TODO make this less crap
          mailer = Mailer.new(config.mail_sender, config.mail_subject, config.mail_body)

          config.graders.graders.select(&:archive_path).each {|grader|
            mailer.send(grader.email, grader.archive_path)
          }
        end
        MAIL_LOGIC

        # Print a final report
        Logger.log_output "Done! Report:"
        Logger.log_output "\tTotal Submissions: #{submissions.size}"
        Logger.log_output "\tGrader Distributions:"
        assignments.each {|g, ss|
          Logger.log_output "\t\t#{g.id} (workload: #{g.workload}): #{ss.size}"
        }
      end
    end
  end
end