require File.dirname(__FILE__) + '/test_helper'
require 'test/unit'
require 'lib/preferable'

class SerializableBase
  include Preferable
  attr_accessor :preferences
  
  def self.serialize(what)
  end
  
  def read_attribute(att_name)
    send att_name.to_sym
  end
  
  def write_attribute(name, val)
    send "#{name}=".to_sym, val
  end
  

end

class Base < SerializableBase
  preference :base_boolean, :default => false, :group=> :base
end

class Sub1 < Base
  preference :sub_1_pref, :default => 'Hello there'
end

class Unrelated < SerializableBase
  include Preferable
  preference :unrelated,
             :default=> true,
             :group=> :group1

  preference :different_group,
             :default=> false,
             :group => :group2
  preference :options,
             :group=> :group2,
             :default=> 'One',
             :options=> ['One','Two','Three']
end

class UnrelatedSub < Unrelated
  preference :unrelated_sub_pref , :default => 'Kitchen'
  preference :another_pref, :default=> false, :group=> :group1
  preference :number_pref, :default=>52, :group => :group1
end

class PreferencesTest < ActiveSupport::TestCase
 
  def test_preferences_added_methods
    sub = Sub1.new
    assert_equal false, sub.base_boolean
    assert_equal 'Hello there', sub.sub_1_pref
    sub.base_boolean = true
    sub.sub_1_pref = "Goodbye"
    assert_equal true, sub.base_boolean
    assert_equal "Goodbye", sub.sub_1_pref
  end
 
  def test_preference_inheritence
    assert_equal [:base_boolean], Base.pref_names
    assert_equal [:base_boolean, :sub_1_pref], Sub1.pref_names
    assert_equal [:unrelated, :different_group, :options,], Unrelated.pref_names
    assert_equal [:unrelated, :different_group, :options, :unrelated_sub_pref, :another_pref, :number_pref], UnrelatedSub.pref_names
  end
  
  def test_metadata
    meta = UnrelatedSub.pref_meta[:unrelated]
    assert meta
    assert_equal true, meta.default
    assert_equal :group1, meta.group
    
    meta = UnrelatedSub.pref_meta[:unrelated_sub_pref]
    assert_equal nil, meta.group
    assert_equal 'Kitchen' , meta.default
    
  end
  
  def test_specific_metadata
    meta = UnrelatedSub.pref_meta_for(:unrelated)
    assert meta
    assert_equal true, meta.default
    assert_equal :group1, meta.group
  end
  
  def test_group_names
    names = UnrelatedSub.pref_group_names
    assert_equal ["", "group1", "group2"], names
  end
  
  def test_single_pref
    u = UnrelatedSub.new
    assert_equal true, u.pref(:unrelated)
    assert_equal 'Kitchen', u.pref(:unrelated_sub_pref)
    u.unrelated_sub_pref = 'Bathroom'
    assert_equal 'Bathroom', u.unrelated_sub_pref
  end
  
  def test_all_preferences
    u = UnrelatedSub.new
    prefs = u.all_preferences
    expect = {:unrelated => true,
              :different_group=> false,
              :unrelated_sub_pref =>'Kitchen',
              :options=> 'One',
              :number_pref => 52,
              :another_pref=> false}
    assert_equal expect , prefs
  end
  
  def test_get_prefs_by_group
    groups = UnrelatedSub.new.prefs_in_group(:group1)
    assert_equal({:unrelated => true, :another_pref=> false, :number_pref=> 52}, groups)
  end
  
  def test_preference_groups
    assert_equal [:group1, :group2,nil] , UnrelatedSub.pref_groups
  end
  
  def test_infer_type_from_default
    assert_equal :string, UnrelatedSub.pref_meta_for(:unrelated_sub_pref).type
    assert_equal :boolean, UnrelatedSub.pref_meta_for(:another_pref).type
    assert_equal :string, UnrelatedSub.pref_meta_for(:options).type
    assert UnrelatedSub.pref_meta_for(:options).has_options?
    assert_equal :fixnum, UnrelatedSub.pref_meta_for(:number_pref).type
  end
  
  class Safety < SerializableBase
    preference :float, :default=> 30.28
    preference :fixnum, :default => 28
    preference :string , :default=> "hello there"
    preference :boolean, :default=> false
  end
  
  def test_type_safety
    s = Safety.new
    assert_equal 30.28, s.float
    assert_equal 28, s.fixnum
    assert_equal "hello there", s.string
    assert_equal false, s.boolean
    
    #play around a bit
    s.float = "392.888"
    assert_equal 392.888, s.float
    s.fixnum= s.float
    assert_equal 392, s.fixnum
    s.boolean = 1
    assert_equal true, s.boolean
    s.boolean = 0
    assert_equal false, s.boolean
    s.boolean = "false"
    assert_equal false, s.boolean
    s.boolean = "true"
    assert_equal true, s.boolean
  end
 
 class Sequence < SerializableBase
   preference :first, :default => false, :group => :g1
   preference :second, :default=> false, :group => :g2
   preference :third, :default => false, :group => :g1
   preference :fourth, :default => false, :group => :g2
 end
 
 def test_ordering
  expected_sequence = [:first,:second,:third,:fourth]
  x = Sequence.new
  assert_equal expected_sequence, Sequence.pref_names
  assert_order_by_sequence(x,expected_sequence)
  assert_order_by_sequence(x,[:first,:third],:g1)
  assert_order_by_sequence(x,[:second,:fourth],:g2)
 end
 
 def assert_order_by_sequence(obj,seq, group = :all)
   idx = 0
   obj.each_pref_in_group(group) do |name, meta, value|
     assert name
     assert meta
     assert !value.nil?
     assert_equal seq[idx], name
     idx += 1
   end
   assert idx > 0
   
 end
 
 class TypeSafety < SerializableBase
   preference :symbol,
              :default=> :one
   preference :symbol_options,
              :options=>[:one,:two,:three]
 end
 
 def test_symbol_type_correct
   x = TypeSafety.new
   x.symbol = :two
   assert_equal :two, x.symbol
   x.symbol = 'three'
   assert_equal :three, x.symbol
   assert_equal Symbol, x.symbol.class
 end
 
 def test_symbol_options_type_correct
   x = TypeSafety.new
   assert_equal :one, x.symbol_options
   x.symbol_options = :two
   assert_equal :two, x.symbol_options
   x.symbol_options = :seven
   assert_equal :two, x.symbol_options
   x.symbol_options = 'one'
   assert_equal :one, x.symbol_options
 end
 
 class Queryable < SerializableBase
  def self.before_save(method_to_call)
    @@before_saves ||= []
    @@before_saves << method_to_call
  end

  def foo=(val)
     @foo = val
  end
   
  def foo
     @foo
  end
   
  def save
    @@before_saves.each do |name|
      self.send name
    end
  end
  
   preference :foo, :default=> false,
              :queryable => :true
   
 end
 
 def test_queryable_pref
   d = Queryable.new
   assert_equal false, d.foo
   d.save
   assert_equal false, d.foo
   d.foo = true
   assert_equal true, d.foo
  
 end
 
 
end