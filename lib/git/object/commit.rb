require 'date'
require 'time'

class Git::Object::Commit < Git::Object
  include Proxyable
    
  SAFE_STRING_BOUNDARY = %r{[^\ .,:;<>"']}
  SAFE_STRING_CONTENTS = %r{[^\000\012<>]}
  
  SAFE_STRING = %r{
    #{SAFE_STRING_BOUNDARY} |
    #{SAFE_STRING_BOUNDARY}
    #{SAFE_STRING_CONTENTS}*
    #{SAFE_STRING_BOUNDARY}
  }x
  
  DATE = %r{\d+}
  TZ   = %r{[+-]\d{2}\d{2}}
  
  INPUT_FORMAT = %r{^
       tree     \ (\w{40})\012
    (?:parent   \ (\w{40})\012)*
       author   \ (#{SAFE_STRING})\ <(#{SAFE_STRING})>\ (#{DATE})\ (#{TZ})\012
       committer\ (#{SAFE_STRING})\ <(#{SAFE_STRING})>\ (#{DATE})\ (#{TZ})\012
    \012
  }xm
  
  attr_proxied :author
  attr_proxied :committer
  attr_proxied :message
  
  attr_proxied :tree
  attr_proxied :parents
  
  attr_proxied :authored_at
  attr_proxied :committed_at
  
  def initialize(tree = nil, message = nil, *parents)
    self.tree      = tree
    self.committer = Git::Author.default
    self.author    = self.committer
    self.parents   = parents
    self.message   = message
    
    self.authored_at  ||= DateTime.now
    self.committed_at ||= DateTime.now
  end
  
  private
  
  def _dump
    format  = [ "tree %s" ]
    format += [ "parent %s" ] * parents.length
    format += [ "author %s <%s> %s %s"]
    format += [ "committer %s <%s> %s %s" ]
    format += [ "" ]
    format += [ "%s" ]
    
    content = []
    content.push(tree.hash)
    content.push(*parents.map {|p| p.hash })
    content.push(author.name, author.email)
    content.push(*format_timestamp(authored_at))
    content.push(committer.name, committer.email)
    content.push(*format_timestamp(committed_at))
    content.push(message)

    format.join("\012") % content
  end
  
  def _load(dump)
    proxy!(dump) do
      fields = dump.split(INPUT_FORMAT)
      fields.shift
      
      parents = fields.length - 10 # 1 tree, 4 author, 4 commit, 1 message
      
      self.tree    = Git::Object::Tree.find(fields.shift)
      self.parents = (1..parents).map { Git::Object::Commit.find(fields.shift) }
      
      self.author       = Git::Author.new(fields.shift, fields.shift)
      self.authored_at  = parse_timestamp(fields.shift, fields.shift)
      self.committer    = Git::Author.new(fields.shift, fields.shift)
      self.committed_at = parse_timestamp(fields.shift, fields.shift)
      
      self.message      = fields.shift
    end
  end
  
  def format_timestamp(date_time)
    offset      = (24 * 60 * 60) * date_time.offset
    sign        = (offset > 0 ? '+' : '-')
    hours, mins = (offset.abs / 60).divmod(60)
    
    [date_time.strftime("%s"), sprintf("%s%02d%02d", sign, hours, mins)]
  end
  
  def parse_timestamp(seconds, offset)
    DateTime.strptime(seconds, '%s').new_offset(offset)
  end
end