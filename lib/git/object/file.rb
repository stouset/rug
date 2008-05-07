class Git::Object::File
  attr_accessor :name
  attr_accessor :mode
  attr_writer   :blob
  
  def initialize(params = {})
    name = params[:name]
    mode = params[:mode] || '0644'
    
    (@blob = params[:blob]) || (@hash = params[:hash])
  end
  
  def blob
    @blob || Git::Object
  end
end