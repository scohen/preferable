module Preferable
  def self.included(recipient)
    recipient.extend(PreferableClassMethods)
    recipient.class_eval do
      include PreferableInstanceMethods
    end
  end

  module PreferableClassMethods
    def pref_names
      order
    end
    
    def pref_meta
      @pref_meta ||= {}
    end

    def order
      @order ||= []
    end
    
    def pref_meta_for(name)
      pref_meta[name] || PreferenceMetaData.new(:name=> name)
    end
    
    def pref_description(pref_name)
      pref_meta[pref_name].description
    end
    
    def pref_groups
      pref_meta.collect{|k,v| v.group}.uniq
    end
    
    def pref_group_names
      pref_groups.collect{|k,v| k.to_s}.sort
    end
    
    def preference(name, options = {})
      opts = options.merge({:description=>"", :group=>:default})
      serialize :preferences
      meta = PreferenceMetaData.new(options)
      define_preference(name,meta)
    end
    
    def define_preference(name, meta)
      pref_meta[name] = meta
      order << name unless order.include? name
      self.send(:define_method, "#{name.to_s}=".to_sym) do |val|
        p = read_attribute(:preferences) || {}
        p[name] = to_correct_type(val, meta)
        write_attribute(:preferences,p)
      end
      
      self.send(:define_method, name.to_sym) do
        prefs = read_attribute(:preferences)
        if prefs
          prefs[name] || meta.default
        else
          meta.default
        end
      end
      nil
    end
    
    def inherited(subclass)
      pref_meta.each do |name, meta|
        subclass.class_eval %{
          define_preference name, meta
        }
      end
      super(subclass)
    end
    

    
  end
  
  module PreferableInstanceMethods
    def pref(name)
      self.send name.to_sym
    end
    
    def pref=(name,value)
      self.send("#{name}=".to_sym, value)
    end
    
    def prefs_in_group(group=:all)
      if group == :all
        return all_preferences
      else
        self.class.send(:pref_meta).inject({}) do |acc,p|
          name = p[0]
          meta = p[1]
          acc[name] = pref(name) if meta.group == group
          acc
        end
      end
    end
    
    def all_preferences
      self.class.send(:pref_names).inject({}) do |acc,name|
        acc[name] = pref(name)
        acc
      end
    end
    
   private
    def to_correct_type(val,meta)
      case meta.type
      when :string
        val.to_s
      when :boolean
        if val == "true"
          true
        elsif val == true || val == false
          val
        else
          val.to_i != 0 
        end
      when :fixnum
        val.to_i
      when :float
        val.to_f
      end
    end
  end
  
  class PreferenceMetaData
    attr_accessor :group
    attr_accessor :description
    attr_accessor :default
    attr_accessor :type
    attr_accessor :options
    attr_reader :pref_order
    
    def initialize(options={})
      @group = options[:group]
      @description = options[:description]
      @default = options[:default]
      @options = options[:options]
      if @options
        @type = :option
      else
        @type = options[:type] || infer_type_from_default(@default.class)
      end
      @pref_order = options[:pref_order] 
    end
    
    def to_options
      {:group => group,
       :description => description,
       :default => default,
       :type => type,
       :options => options,
       :pref_order => pref_order
      }
    end
    
    private
    def infer_type_from_default(clazz)
      case clazz.to_s
        when "TrueClass", "FalseClass"
          :boolean
        else
          clazz.to_s.downcase.to_sym
        end
      end
  end
end
