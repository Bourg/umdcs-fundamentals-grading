Gem::Specification.new do |s|
  s.name        = 'spd'
  s.version     = '0.0.0'
  s.date        = '2018-01-19'
  s.summary     = "A grading workflow tool for the Systematic Program Design course sequence at UMD"
  s.description = "This tool can be used to generate mock testing setups, distribute submissions to graders, and recollect graded assignments into formats for the submit server and for student return."
  s.homepage    = "http://bourg.me"
  s.authors     = ["Austin Bourgerie"]
  s.email       = 'abourg@cs.umd.edu'
  s.files       = Dir.glob("lib/**/*")
  s.executables << "spd"
  s.license     = "MIT"
end
