require 'amazing_nested_set'
require 'set_data_container'
 
ActiveRecord::Base.class_eval do
  include NormElton::Acts::NestedSet
end