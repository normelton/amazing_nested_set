class SetDataContainer
  attr_accessor :set_id
  
  def initialize(options, seed)
    @options = options
    @set_id = seed.set_id
    @set_members = nil
    
    @seed = seed
  end
  
  def set_id
    @set_id ||= @options[:class].maximum(@options[:set_column]).to_i.next
  end
  
  def register_node(node)
    unless set_members.include?(node)
      set_members << node
    end
    
    # replace_node node
    sort
  end
  
  def unregister_node(node)
    set_members.delete(node)
  end
  
  def replace_node(node)
    unless node.new_record?
      set_members.each_index do |i|
        if (set_members[i].id == node.id)
          set_members[i] = node
        end
      end
    end
  end
  
  def infer_self
    set_members.each do |node|
      node.infer_container(self)
    end
  end
  
  def sort
    set_members.sort!{|a,b| a.left <=> b.left}
  end
  
  def ==(val)
    self.object_id == val.object_id
  end
  
  def members(from)
    if (@set_members.nil?)
      if (@set_id.nil?)
        @set_members = [@seed]
      else
        @set_members = @options[:class].find :all, :conditions => { @options[:set_column].to_sym => @set_id }, :order => @options[:left_column].to_sym
      end
      
      replace_node from
      infer_self
    end
    
    @set_members
  end
  
  private
  
  def set_members
    members(nil)
  end
end