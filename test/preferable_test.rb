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
end

class UnrelatedSub < Unrelated
  preference :unrelated_sub_pref , :default => 'Kitchen'
  preference :another_pref, :default=> false, :group=> :group1
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
    assert_equal [:unrelated, :different_group], Unrelated.pref_names
    assert_equal [:unrelated, :different_group, :unrelated_sub_pref, :another_pref], UnrelatedSub.pref_names
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
              :another_pref=> false}
    assert_equal expect , prefs
  end
  
  def test_get_prefs_by_group
    groups = UnrelatedSub.new.prefs_in_group(:group1)
    assert_equal({:unrelated => true, :another_pref=> false}, groups)
  end
  
  def test_preference_groups
    assert_equal [:group1, :group2,nil] , UnrelatedSub.pref_groups
  end
  
 
end