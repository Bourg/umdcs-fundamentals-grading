require 'pathname'
require 'fileutils'

require 'common/fileops'

SETUP_DIRNAME = 'setup'
CANON_DIRNAME = 'canon'

module SPD
  module Ops
    class Sanity
      def self.do_sanity(output_dir, expected_files)
        Dir.chdir(output_dir)
        Dir.mkdir(SETUP_DIRNAME)
        Dir.mkdir(CANON_DIRNAME)

        # Create test files and canonical files for each expected file
        fuzzed_filenames = []
        expected_files.each {|expected_file|
          fuzzed_filename = "#{File.basename(expected_file)}_exists"
          fuzzed_filenames << fuzzed_filename

          File.open(File.join(SETUP_DIRNAME, fuzzed_filename), "w") {|f|
            f.write "#!/bin/bash\nls #{expected_file}"
          }

          filepath = File.join(CANON_DIRNAME, expected_file)
          FileUtils.mkpath(File.dirname(filepath))
          FileUtils.touch(filepath)
        }

        # Create a test config file for the submit server
        File.open(File.join(SETUP_DIRNAME, "test.properties"), "w") {|f|
          f.puts "build.language=ruby"
          f.puts "build.make.command=make"
          f.puts "build.make.file=Makefile"
          f.puts "test.class.public=#{fuzzed_filenames.join(" ")}"
          f.puts "test.timeout.testProcess=20"
          f.puts "test.output.maxBytes=1048576"
        }

        # Create a blank makefile for the submit server
        File.open(File.join(SETUP_DIRNAME, "Makefile"), "w") {|f|
          f.puts "all:"
          f.puts "clean:"
        }

        # Zip everything up and remove the working directories
        [SETUP_DIRNAME, CANON_DIRNAME].each {|output_dirname|
          # Save the starting point
          old_dir = Dir.pwd

          # Switch into the working directory to zip flat
          Dir.chdir(output_dirname)
          `zip -r #{File.join(old_dir, "#{File.basename(output_dirname)}.zip")} *`

          # Switch back up and clean up
          Dir.chdir(old_dir)
          FileUtils.rm_r(output_dirname)
        }
      end
    end
  end
end