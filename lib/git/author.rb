require 'etc'
require 'socket'

class Git::Author
  attr_writer :name
  attr_writer :email
  
  def self.default
    new
  end
  
  def self.parse(string)
    match = %r{^\s+([^<]+)<([^>]+)>\s+$}
    name  = match[1].strip
    email = match[2].strip
    new(name, email)
  end
  
  def initialize(name = nil, email = nil)
    self.name  = name
    self.email = email
  end
  
  def name
    @name || passwd.gecos
  end
  
  def email
    @email || "#{passwd.name}@#{Socket.gethostname}"
  end
  
  private
  
  def passwd
    @passwd ||= Etc.getpwuid(Process.uid)
  end
end