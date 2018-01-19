require 'FileUtils'

# A simple Result type
class Result
  attr_reader :value
  private_class_method :new

  def initialize(type, value)
    @type = type
    @value = value
  end

  def self.success(value = nil)
    return new(true, value)
  end

  def self.failure(value = nil)
    return new(false, value)
  end

  def success?
    return @type
  end

  def failure?
    return !success?
  end
end

# Helpers for unified output/logging
def log_output(output)
  STDOUT.puts(output)
end

def log_warning(output)
  STDOUT.puts("[WARN]: #{output}")
end

def log_error(output)
  STDERR.puts("[ERROR]: #{output}")
end

def log_fatal(output, code = 1)
  STDERR.puts("[FATAL]: #{output}")
  exit(code)
end

################################################################################
# Data Models                                                                  #
################################################################################

class Graders
  # initialize : Array<Grader>
  def initialize(graders)
    @graders = graders
  end

  # assign : Array<UngradedSubmission> -> Result
  # Success contains assignment of submissions to graders weighted by workload
  # Failure contains same results as the validate method, or additionally:
  # - [:invalid_submissions, Array<UngradedSubmission>]
  def assign(submissions)

    # Perform validation on graders and return failure if it occures
    validation_graders = validate
    return validation_graders if validation_graders.failure?

    # Perform validation on submissions, assuming they aren't null
    invalid_submissions = submissions.map(&:validate).select(&:failure?)
    return Result.failure([:invalid_submissions, invalid_submissions]) unless invalid_submissions.empty?

    # At this point, assume the graders and submissions are both valid, i.e.:
    # - Non-zero number of identified graders with a net positive workload
    # - Some number of submissions with known owners and file locations

    # Determine which graders are active, sorted from greatest to least workload
    active_graders = @graders.select(&:active?).sort_by(&:workload).reverse

    # Compute how many submissions should each grader do as a minimum
    grader_counts = active_graders
      .map{|g| [g, g.min_submissions(total_workload, submissions.size)]}
      .to_h

    unassigned_submissions = submissions.size - grader_counts.values.reduce(:+)

    raise 'BAD MATH, NEGATIVE UNASSIGNED SUBMISSIONS' if unassigned_submissions < 0

    # So long as there are submissions needing a grader, spread it around
    # In theory, this loop should never touch a grader more than once
    next_responsible_grader = 0
    while unassigned_submissions > 0
      grader_counts[active_graders[next_responsible_grader]] += 1

      next_responsible_grader += 1
      next_responsible_grader %= active_graders.size
      unassigned_submissions -= 1
    end

    # Translate the number of submissions to grade into concrete submissions
    result = {}
    remaining_submissions = submissions.dup
    grader_counts.each{|g, n|
      if n > 0
        result[g] = remaining_submissions.take(n)
        remaining_submissions = remaining_submissions.drop(n)
      end
    }

    return Result.success(result)
  end

  # validate : () -> Result
  # Returns a result where failure contains one of the following:
  # - [:no_workload]
  # - [:invalid_graders, Array<Graders>]
  # Success contains nil
  def validate
    return Result.failure([:no_workload]) unless @graders

    invalids = @graders.reject(&:valid?)
    return Result.failure([:invalid_graders, invalids]) unless invalids.empty?

    return Result.failure([:no_workload]) unless total_workload > 0

    return Result.success
  end

  # total_workload : () -> Float
  # Returns the total workload of all listed graders
  def total_workload
    @graders.map(&:workload).reduce(:+)
  end
end

class Grader
  attr_reader :id, :workload

  # Create a new grader by email and workload modifier
  # id may be an email or any other piece of identifying information
  def initialize(id, workload = 1)

    # Extract the username from an email address if an email is given
    if id =~ /^(.+)@.+\..+$/
      @id = $1
    else
      @id = id
    end

    @workload = workload.to_f
  end

  def valid?
    return id && !id.empty? && workload && workload >= 0
  end

  def active?
    return workload > 0
  end

  # min_submissions : Float Integer -> Integer
  # Given the workload cost of a submission, compute the minimum number of
  # submissions that should be assigned to this grader
  def min_submissions(total_workload, num_submissions)
    return (num_submissions * @workload / total_workload).to_i
  end
end

# Represents a single ungraded submission by who submitted it and its path
class UngradedSubmission
  attr_accessor :student_id, :path

  def initialize(student_id, path)
    @student_id = student_id
    @path = path
  end

  # validate : () -> Result
  # On success, returns no explicit value
  # On failure, returns one of the following values:
  # - :empty_id
  # - :invalid_path
  def validate
    return Result.failure(:empty_id) unless @student_id && !@student_id.empty?
    return Result.failure(:invalid_path) unless Dir.exist? @path
    return Result.success
  end
end

# Determine the directory to read from
if ARGV.size < 1 || !Dir.exist?(ARGV[0])
  log_fatal "First argument must be the directory containing submissions"
end
submissions_dir = ARGV[0]

# Determine the directory to write to
if ARGV.size < 2
  log_fatal "Second argument must be a directory to output to"
end

output_dir = ARGV[1]

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
