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


