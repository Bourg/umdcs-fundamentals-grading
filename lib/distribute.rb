require 'FileUtils'

require 'entities'
require 'logger'

def do_distribute(args)
  # Determine the directory to read from
  if args.size < 1 || !Dir.exist?(args[0])
    log_fatal "First argument must be the directory containing submissions"
  end
  submissions_dir = args[0]

  # Determine the directory to write to
  if args.size < 2
    log_fatal "Second argument must be a directory to output to"
  end

  output_dir = args[1]

  if Dir.exist?(output_dir)
    print "The directory #{output_dir} already exists - would you like to overwrite? (Y/n): "
    answer = STDIN.readline.strip
    if answer =~ /^[yY](?:es)?$/
      rmd = FileUtils.rm_r(output_dir)
      log_fatal "Couldn't remove the output directory" unless rmd
    else
      log_fatal "Please choose a different output directory or remove the current one"
    end
  end

  # Determine the staff list
  # TODO make this procedural from an input file / allow simple even split mode
  graders = Graders.new([
    Grader.new("abourg@cs.umd.edu", 1),
    Grader.new("camoy@cs.umd.edu", 1),
    Grader.new("jack@cs.umd.edu", 1),
    Grader.new("tharris@cs.umd.edu", 1),
    Grader.new("sbarham@cs.umd.edu", 1.8),
    Grader.new("rzehrung@cs.umd.edu", 1)].shuffle)

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
          log_warning "Found an invalid submission by #{submitter_id} at #{submission_dir}: #{submission_validation.value.inspect}"
        end
      else
        log_warning "The source subdirectory #{subdir} doesn't match the regex"
      end
    end
  }
  submissions.sort_by!(&:student_id)

  # Attempt to assign submissions to graders
  assignments_result = graders.assign(submissions)
  if assignments_result.failure?
    log_fatal "Failed to assign submissions to graders: #{assignments_result.value.inspect}"
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

  Dir.chdir(output_dir)
  Dir.foreach("."){|subdir|
    unless subdir == "." || subdir == ".."
      `tar czf #{subdir}-submissions.tar.gz #{subdir}`
      FileUtils.rm_r(subdir)
    end
  }

  log_output "Done! Report:"
  log_output "\tTotal Submissions: #{submissions.size}"
  log_output "\tGrader Distributions:"
  assignments.each{|g, ss|
    log_output "\t\t#{g.id} (workload: #{g.workload}): #{ss.size}"
  }
end
