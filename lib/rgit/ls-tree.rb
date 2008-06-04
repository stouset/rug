require 'rgit'

class Rgit::LsTree < Rgit
  def main(tree, *paths)
    tree  = Git::Object.find(tree).to_tree
    paths.map! {|path| path.to_path }
    
    # need to work on _some_ path
    if paths.empty?
      pwd = Pathname.pwd
      pwd = pwd.relative_path_from(Git::Repository.work_dir)
      paths.unshift(pwd)
    end
  end
  
  private
    
  protected
  
  def parser
    OptionParser.new do |opts|
      opts.banner = "Usage: rgit-ls-tree [options] <tree-ish> [paths...]"
      
      opts.on('-d', '--dir',
        'show only trees; implies -t') \
        {|settings.dir| settings.show_trees = settings.dir }
      
      opts.on('-r', '--recurse',
        'recurse into sub-trees') \
        {|settings.recursive|}
      
      opts.on('-t', '--tree',
        'show trees even when recusing into them') \
        {|settings.show_trees|}
      
      opts.on('-l', '--long',
        'also show the size of files') \
        {|settings.long|}
      
      opts.on('-z', '--null',
        'terminate lines with \0 rather than \n') \
        { settings.terminator = "\0" }
      
      opts.on('--name-only', '--name-status',
        'list only filenames') \
        {|settings.name_only|}
      
      opts.on('--abbrev [n]',
        'shorten the hex string from 40 (default 7)') \
        {|settings.abbrev| settings.abbrev ||= 7 }
      
      opts.on('--full-name',
        'always show paths relative to the working dir') \
        {|settings.full_paths|}
    end
  end
  
  def defaults
    OpenStruct.new(
      :dir        => false,
      :recurse    => false,
      :show_trees => false,
      :long       => false,
      :terminator => "\n",
      :name_only  => false,
      :abbrev     => 40,
      :full_paths => false
    )
  end
end
