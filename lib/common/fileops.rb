module SPD
  module Common
    module FileOps
      # subdirs_of : String Regexp -> Array<String>
      # Collects the directory names of all child directories whose names match the given pattern
      def self.subdirs_of(dir, pattern = nil)
        subdirs = Dir.entries(dir)
                     .reject {|subdir| subdir == '.' || subdir == '..'}
                     .select {|subdir| Dir.exist? File.join(dir, subdir)}

        # If a pattern is given, coerce it into a regexp and filter subdir names
        if pattern
          pattern = Regexp.new(pattern) unless pattern.is_a? Regexp
          subdirs.select! {|subdir| subdir =~ pattern}
        end

        subdirs
      end
    end
  end
end

