require 'test/unit'

require 'rubygems'
require 'active_record'

$:.unshift File.dirname(__FILE__) + "/../lib"
require File.dirname(__FILE__) + "/../init"

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

class Default < ActiveRecord::Base
  acts_as_nested_set
end

def setup_db
  ActiveRecord::Base.logger
  ActiveRecord::Schema.define(:version => 1) do
    create_table :nodes do |t|
      t.integer :id
      t.integer :set_id
      t.float :rgt
      t.float :lft
      t.string :name
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Node < ActiveRecord::Base
  set_table_name "Nodes"
  
  acts_as_nested_set
end

class SortedNode < ActiveRecord::Base
  set_table_name "Nodes"
  
  include Comparable
  
  acts_as_nested_set :autosort => true

  def <=>(val)
    self.name <=> val.name
  end
end

class SingleNodeTestCase < Test::Unit::TestCase
  def setup
    setup_db
  end

  def test_single_node
    node = Node.new(:name => "root")
    node.save
    
    assert_equal  node.name, "root"
    assert        node.root?
    assert        node.leaf?
    assert_equal  node.root, node
    assert_equal  node.children, []
    assert_equal  node.self_and_children, [node]
    assert_equal  node.direct_children, []
    assert_equal  node.siblings, []
    assert_nil    node.parent
    assert_equal  node.ancestors, []
    assert_equal  node.depth, 0
    assert_equal  node.to_range, 1..2
  end
  
  def teardown
    teardown_db
  end
end

class MultipleNodeTestCase < Test::Unit::TestCase
  def setup
    setup_db
  end

  def multi_test(n_root, n_cars, n_trucks, n_coupes, n_sedans)
    assert        n_root.root?
    assert        !n_cars.root?
    assert        !n_root.leaf?
    assert        n_coupes.leaf?
    assert_equal  n_root.root, n_root
    assert_equal  n_cars.root, n_root
    
    assert_equal  n_root.children, [n_cars, n_coupes, n_sedans, n_trucks]
    assert_equal  n_root.self_and_children, [n_root, n_cars, n_coupes, n_sedans, n_trucks]
    assert_equal  n_root.direct_children, [n_cars, n_trucks]

    assert_equal  n_cars.siblings, [n_trucks]
    assert_equal  n_coupes.parent, n_cars
    assert_equal  n_coupes.ancestors, [n_cars, n_root]
    assert_equal  n_coupes.self_and_ancestors, [n_coupes, n_cars, n_root]
    assert_equal  n_coupes.depth, 2
  end
  
  def test_multiple_nodes
    n_root = Node.new(:name => "root")
    n_cars = Node.new(:name => "cars")
    n_trucks = Node.new(:name => "trucks")
    n_coupes = Node.new(:name => "coupes")
    n_sedans = Node.new(:name => "sedans")

    n_root.add_as_child(n_cars)
    n_root.add_as_child(n_trucks)

    n_cars.add_as_child(n_coupes)
    n_cars.add_as_child(n_sedans)
    
    multi_test n_root, n_cars, n_trucks, n_coupes, n_sedans
    
    
    n_root.self_and_children.each{|n| n.save}

    n_root = Node.find n_root.id
    
    assert_equal  n_root.children.size, 4
    
    n_cars = n_root.children.select{|n| n.name == "cars"}.first
    n_trucks = n_root.children.select{|n| n.name == "trucks"}.first
    n_coupes = n_root.children.select{|n| n.name == "coupes"}.first
    n_sedans = n_root.children.select{|n| n.name == "sedans"}.first

    multi_test n_root, n_cars, n_trucks, n_coupes, n_sedans
  end
  
  def teardown
    teardown_db
  end
end

class SortedNodeTestCase < Test::Unit::TestCase
  def setup
    setup_db
  end

  def test_sorted_nodes
    unsorted_root = Node.new(:name => "root")
    unsorted_apple = Node.new(:name => "apple")
    unsorted_banana = Node.new(:name => "banana")
    unsorted_cherry = Node.new(:name => "cherry")

    sorted_root = SortedNode.new(:name => "root")
    sorted_apple = SortedNode.new(:name => "apple")
    sorted_banana = SortedNode.new(:name => "banana")
    sorted_cherry = SortedNode.new(:name => "cherry")
    
    unsorted_root.add_as_child unsorted_cherry
    unsorted_root.add_as_child unsorted_apple
    unsorted_root.add_as_child unsorted_banana
    
    assert_equal unsorted_root.children, [unsorted_cherry, unsorted_apple, unsorted_banana]

    sorted_root.add_as_child sorted_cherry
    sorted_root.add_as_child sorted_apple
    sorted_root.add_as_child sorted_banana
    
    assert_equal sorted_root.children, [unsorted_apple, unsorted_banana, unsorted_cherry]
  end
  
  def teardown
    teardown_db
  end
end

class MovingNodesTest < Test::Unit::TestCase
  def setup
    setup_db
  end
  
  def init()
    # n_root
    #   `- n_cars
    #     `- n_coupes
    #     `- n_sedans
    #   `- n_trucks
    
    n_root = Node.new(:name => "root")
    n_cars = Node.new(:name => "cars")
    n_trucks = Node.new(:name => "trucks")
    n_coupes = Node.new(:name => "coupes")
    n_sedans = Node.new(:name => "sedans")

    n_root.add_as_child(n_cars)
    n_root.add_as_child(n_trucks)

    n_cars.add_as_child(n_coupes)
    n_cars.add_as_child(n_sedans)
    
    [n_root, n_cars, n_trucks, n_coupes, n_sedans]
  end
  
  def test_moving_nodes
    n_root, n_cars, n_trucks, n_coupes, n_sedans = init
    
    assert_equal n_root.direct_children, [n_cars, n_trucks]
    
    n_trucks.add_as_child(n_sedans)
    
    assert_equal n_trucks.direct_children, [n_sedans]
    assert_equal n_cars.direct_children, [n_coupes]
    

    n_root, n_cars, n_trucks, n_coupes, n_sedans = init

    n_trucks.add_as_child(n_cars)
    
    assert_equal n_root.direct_children, [n_coupes, n_sedans, n_trucks]
    assert_equal n_cars.children, []
    

    n_root, n_cars, n_trucks, n_coupes, n_sedans = init

    n_trucks.add_as_child(n_cars, true)
    
    assert_equal n_root.direct_children, [n_trucks]
    assert_equal n_trucks.direct_children, [n_cars]
    assert_equal n_trucks.children, [n_cars, n_coupes, n_sedans]
    

    n_root, n_cars, n_trucks, n_coupes, n_sedans = init

    n_cars.add_as_left(n_coupes)
    n_cars.add_as_right(n_sedans)
    
    assert_equal n_root.direct_children, [n_coupes, n_cars, n_sedans, n_trucks]
  end
  
  def teardown
    teardown_db
  end
end

class MultipleTreeTest < Test::Unit::TestCase
  def setup
    setup_db
  end

  def test_multiple_trees
    n_cars = Node.new(:name => "cars")
    n_coupes = Node.new(:name => "coupes")
    n_sedans = Node.new(:name => "sedans")

    n_cars.add_as_child(n_coupes)
    n_cars.add_as_child(n_sedans)
    n_cars.save

    n_fruits = Node.new(:name => "fruits")
    n_apple = Node.new(:name => "apple")
    n_banana = Node.new(:name => "banana")

    n_fruits.add_as_child(n_apple)
    n_fruits.add_as_child(n_banana)
    n_fruits.save
    
    assert  n_cars.set_members.object_id == n_coupes.set_members.object_id
    assert  n_cars.set_members.object_id != n_fruits.set_members.object_id
    
    n_banana.add_as_right(n_coupes)
    
    assert  n_banana.set_members.object_id == n_coupes.set_members.object_id
    assert_equal  n_fruits.children.size, 3
    assert_equal  n_cars.children.size, 1
  end
  
  def teardown
    teardown_db
  end
end
