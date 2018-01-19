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


