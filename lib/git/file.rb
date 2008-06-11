class Git::File
  attr_reader   :path
  attr_accessor :contents
  
  attr_accessor :ctime
  attr_accessor :mtime
  attr_accessor :dev
  attr_accessor :inode
  attr_accessor :mode
  attr_accessor :uid
  attr_accessor :gid
  
  def initialize(filename, contents = nil, attrs = nil)
    self.path     = filename
    self.contents = contents || path.read
    
    if attrs
      self.ctime = attrs[:ctime]
      self.mtime = attrs[:mtime]
      self.dev   = attrs[:dev]
      self.inode = attrs[:inode]
      self.mode  = attrs[:mode]
      self.uid   = attrs[:uid]
      self.gid   = attrs[:gid]
    else
      stat = path.lstat
      
      self.ctime = path.ctime
      self.mtime = path.mtime
      self.dev   = stat.dev
      self.inode = stat.ino
      self.mode  = stat.mode
      self.uid   = stat.uid
      self.gid   = stat.gid
    end
  end
  
  def path=(filename)
    @path = filename.to_path
  end
  
  def id
    Git::Object.id(:blob, contents)
  end
  
  def size
    contents.length
  end
end