require 'fileutils'

require 'entities'
require 'common/record'
require 'common/logger'

include Entities

$RECORD_FILENAME = "record.csv"

def do_distribute(config, args)
  log_failure "Missing arguments" unless config && args

  # Determine the directory to read from
  if args.size < 1 || !Dir.exist?(args[0])
    Common.log_fatal "First argument must be the directory containing submissions"
  end
  submissions_dir = args[0]

  # Determine the directory to write to
  if args.size < 2
    Common.log_fatal "Second argument must be a directory to output to"
  end

  output_dir = args[1]

  if Dir.exist?(output_dir)
    print "The directory #{output_dir} already exists - would you like to overwrite? (Y/n): "
    answer = STDIN.readline.strip
    if answer =~ /^[yY](?:es)?$/
      rmd = FileUtils.rm_r(output_dir)
      Common.log_fatal "Couldn't remove the output directory" unless rmd
    else
      Common.log_fatal "Please choose a different output directory or remove the current one"
    end
  end

  # Identify submissions in the input directory
  submissions = []
  Dir.foreach(submissions_dir){|subdir|
    unless subdir == "." || subdir == ".."
      # If the subdirectory matches the expected format
      if subdir =~ /^(\w+)__\d+$/
        submitter_id = $1
        submission_dir = File.join(submissions_dir, subdir)

        submission = UngradedSubmission.new(submitter_id, submission_dir)
        submission_validation = submission.validate

        # If the submission validates, keep it. Otherwise, log a warning.
        if submission_validation.success?
          submissions << submission
        else
          Common.log_warning "Found an invalid submission by #{submitter_id} at #{submission_dir}: #{submission_validation.value.inspect}"
        end
      else
        Common.log_warning "The source subdirectory #{subdir} doesn't match the regex"
      end
    end
  }
  submissions.sort_by!(&:student_id)

  # Attempt to assign submissions to graders
  assignments_result = config.graders.assign(submissions)
  if assignments_result.failure?
    Common.log_fatal "Failed to assign submissions to graders: #{assignments_result.value.inspect}"
  end
  assignments = assignments_result.value

  # Perform filesystem operations to construct grading packages
  FileUtils.mkdir(output_dir)
  assignments.each{|g, ss|
    grader_dir = File.join(output_dir, g.id)
    FileUtils.mkdir(grader_dir)

    ss.each{|s|
      FileUtils.cp_r(s.path, File.join(grader_dir, s.student_id))
    }
  }

  File.open(File.join(output_dir, $RECORD_FILENAME), "w"){|record_file|
    record_file.write(assignments.to_record_csv)
  }

  Dir.chdir(output_dir)
  Dir.foreach("."){|subdir|
    unless subdir == "." || subdir == ".." || !File.directory?(subdir)
      `tar czf #{subdir}-submissions.tar.gz #{subdir}`
      FileUtils.rm_r(subdir)
    end
  }

  Common.log_output "Done! Report:"
  Common.log_output "\tTotal Submissions: #{submissions.size}"
  Common.log_output "\tGrader Distributions:"
  assignments.each{|g, ss|
    Common.log_output "\t\t#{g.id} (workload: #{g.workload}): #{ss.size}"
  }
end
