module NormElton
  module Acts
    module NestedSet
      def self.included(base)
        base.extend(SingletonMethods)
      end
      
      module SingletonMethods
        def acts_as_nested_set(options = {})
          options = {
            :autosort => false,
            :set_column => 'set_id',
            :left_column => 'lft',
            :right_column => 'rgt'
          }.merge(options)
          
          options[:class] = self
          
          if options[:autosort] && !self.include?(Comparable)
            raise ActiveRecord::ActiveRecordError, "Unable to automatically sort a nested set that does not include Comparable"
          end
          
          write_inheritable_attribute :acts_as_nested_set_options, options
          class_inheritable_reader :acts_as_nested_set_options

          include InstanceMethods
          extend ClassMethods
          
          before_create :set_default_left_and_right
          before_save :init_set_id
        end
      end
      
      module InstanceMethods
        def container
          @container ||= SetDataContainer.new(acts_as_nested_set_options, self)
        end
        
        def set_members
          container.members(self)
        end
        
        def children
          set_members.select{|n| self.parent_of? n}
        end
        
        def ancestors
          set_members.select{|n| n.parent_of?(self)}.sort{|a,b| b.left <=> a.left}
        end
        
        def leaf?
          children.empty?
        end

        def root?
          ancestors.empty?
        end

        def root
          set_members.first
        end
        
        def parent
          ancestors.first
        end
        
        def depth
          ancestors.size
        end
        
        def direct_children
          stack = Array.new
          direct_children = Array.new
          
          children.each do |child|
            until (stack.empty? || stack.last.parent_of?(child))
              stack.pop
            end
            
            if (stack.empty?)
              direct_children << child
            end
            
            stack << child
          end
          
          return direct_children
        end
        
        def self_and_children
          [self] + children
        end
        
        def self_and_direct_children
          [self] + direct_children
        end
        
        def self_and_ancestors
          [self] + ancestors
        end
        
        def left
          self[self.class.left_column_name] || 1
        end
        
        def right
          self[self.class.right_column_name] || 2
        end
        
        def siblings(direction = :both)
          if root?
            []
          else
            all_children = parent.direct_children
            
            if (direction == :both)
              all_children - [self]
            elsif (direction == :left)
              all_children.to(all_children.index(self))[0..-2]
            elsif (direction == :right)
              all_children.from(all_children.index(self))[1..-1]
            end
          end
        end
        
        def self_and_siblings(direction = :both)
          if root?
            [self]
          else
            all_children = parent.direct_children
            
            if (direction == :both)
              all_children
            elsif (direction == :left)
              all_children.to(all_children.index(self))[0..-1]
            elsif (direction == :right)
              all_children.from(all_children.index(self))[0..-1]
            end
          end
        end
        
        def parent_of?(other)
          (self.left < other.left) && (self.right > other.right)
        end
        
        def parent_or_self_of?(other)
          (self.left <= other.left) && (self.right >= other.right)
        end
        
        def to_range
          left..right
        end
        
        def add_as_child(node, recurse = false)
          add_node(node, :child, recurse)
        end
        
        def add_as_left(node, recurse = false)
          add_node(node, :left, recurse)
        end
        
        def add_as_right(node, recurse = false)
          add_node(node, :right, recurse)
        end
        
        def infer_container(new_container)
          unless (new_container == @container)
            unless (@container.nil?)
              @container.unregister_node(self)
            end
            
            @container = new_container
            @container.register_node(self)
          end
        end
        
        def infer_set_id(new_set_id)
          set_id = new_set_id
        end
        
        def set_id
          self[self.class.set_id_column_name]
        end
        
        protected
        
        def add_node(node, as = :child, recurse = false)
          dc = direct_children

          if (self.class.autosorted? && as == :child)
            if (dc.empty?)
              window_left = self.left
              window_right = self.right
            else
              right_of = dc.select{|child| child < node}.last
              
              if (right_of.nil?)
                window_left = self.left
                window_right = dc.first.left
              else
                window_left = right_of.right
                
                if (right_of.siblings(:right).empty?)
                  window_right = self.right
                else
                  window_right = right_of.siblings(:right).first.left
                end
              end
            end
            
          elsif (self.class.autosorted?)
            raise ActiveRecord::ActiveRecordError, "Unable to add #{as.to_s} to an autosorted nested set"
            
          elsif (as == :child)
            window_right = self.right
            
            if (dc.empty?)
              window_left = self.left
            else
              window_left = dc.last.right
            end
            
          elsif (root?)
            raise ActiveRecord::ActiveRecordError, "Unable to add a node outside the root"
            
          elsif (as == :left)
            if (siblings(:left).empty?)
              window_left = parent.left
            else
              window_left = siblings(:left).last.right
            end

            window_right = self.left
            
          elsif (as == :right)
            window_left = self.right

            if (siblings(:right).empty?)
              window_right = parent.right
            else
              window_right = siblings(:right).first.left
            end
          end
          
          new_left = window_left + ((window_right - window_left) * 0.33)
          new_right = window_left + ((window_right - window_left) * 0.66)
          
          node.renumber(new_left, new_right, container, recurse)
        end

        def renumber(parent_new_left, parent_new_right, new_container, recurse = false)
          parent_old_left = self.left
          parent_old_right = self.right
          
          parent_old_span = parent_old_right - parent_old_left
          parent_new_span = parent_new_right - parent_new_left
          
          if recurse
            targets = self_and_children
          else
            targets = [self]
          end
          
          targets.each do |n|
            n.left = (((n.left - parent_old_left) / parent_old_span) * parent_new_span) + parent_new_left
            n.right = (((n.right - parent_old_left) / parent_old_span) * parent_new_span) + parent_new_left
            
            n.infer_container(new_container)
          end
          
          set_members.sort!{|a,b| a.left <=> b.left}
        end
        
        def left=(val)
          self[self.class.left_column_name] = val
        end

        def right=(val)
          self[self.class.right_column_name] = val
        end

        private
        
        def set_default_left_and_right
          self.left ||= 1
          self.right ||= 2
        end
        
        def set_id=(val)
          self[self.class.set_id_column_name] = val
        end

        def init_set_id
          self.set_id = container.set_id
        end
      end
      
      module ClassMethods
        def set_id_column_name
          acts_as_nested_set_options[:set_column]
        end
        
        def left_column_name
          acts_as_nested_set_options[:left_column]
        end
        
        def right_column_name
          acts_as_nested_set_options[:right_column]
        end
        
        def autosorted?
          acts_as_nested_set_options[:autosort]
        end

        def roots
          self.find_by_sql "SELECT n1.* FROM #{self.table_name} n1 LEFT JOIN #{self.table_name} n2 ON n1.#{set_id_column_name} = n2.#{set_id_column_name} AND n1.#{left_column_name} > n2.#{left_column_name} WHERE n2.#{primary_key} IS NULL"
        end
      end
    end
  end
end