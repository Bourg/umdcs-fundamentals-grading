Gem::Specification.new do |s|
  s.name        = 'grtools'
  s.version     = '0.0.0'
  s.date        = '2018-01-19'
  s.summary     = "A grading workflow tool for 131/2A"
  s.description = "A small suite of simple tools for the UMD 131/2A grading workflow"
  s.homepage    = "http://bourg.me"
  s.authors     = ["Austin Bourgerie"]
  s.email       = 'abourg@cs.umd.edu'
  s.files       = Dir.glob("lib/**/*")
  s.executables << "grtools"
  s.license     = "MIT"
end
