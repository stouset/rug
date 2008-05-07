class Git::Object
  def self.find(id)
    store = Git::Store::Sha1File.find(id)
    store.object if store
  end
  
  def self.load(type, data)
    klass = const_get(type.capitalize)
    klass.load(data)
  end
  
  def save
    file = Git::Store::Sha1File.new(self).save
    file.hash
  end
  
  def type
    self.class.name.downcase.sub!(/^.*::/, '')
  end
end