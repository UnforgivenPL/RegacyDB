# Model base.
# Integration of RegacyDB with the Ruby on Rails framework.
# 
# RegacyDB - RBatis on Rails 3
# Author::    Miki Olsz (mailto:miki@unforgiven.pl)
# Copyright:: (c) 2009-2011 Unforgiven.pl
# License::   Apache Version 2.0 (see http://www.apache.org/licenses/)
#
# Based on RBatis (where marked)
# Author::    Jon Tirsen  (mailto:jtirsen@apache.org)
# Copyright:: Copyright (c) 2006 Apache Software Foundation
# License::   Apache Version 2.0 (see http://www.apache.org/licenses/)

require 'model_core'

# Author:: Jon Tirsen, 2006
module UnforgivenPL
 module RegacyDB

  # This is class should be used as a base-class when using RBatis with 
  # the Ruby on Rails framework.
  class Base
    include UnforgivenPL::RegacyDB::ModelCore
  
    cattr_accessor :logger
    
    # Author:: Unforgiven.pl
    # Creates new instance can optionally pass Hash to initialize all attributes.
    def initialize(attributes={})
      # this array stores changed fields to be used in update and insert
      # added by Unforgiven.pl
      @tainted_values = []
      # update attributes according to the hash (JT)
      self.attributes = attributes
    end
    
    # Author:: Unforgiven.pl
    # taints the given field (to be updated in nearest insert/update)
    def taint_field(name)
     @tainted_values << name.to_s unless @tainted_values.include?(name.to_s)
    end
    
    # Updates attributes in passed Hash.
    def attributes=(attributes)
      attributes.each do |key, value|
        send("#{key}=", value)
      end
    end
  
    def self.inherited(inherited_by)
      UnforgivenPL::RegacyDB::ModelCore.included(inherited_by)
      class <<inherited_by
        def connection
          ActiveRecord::Base.connection
        end

        def human_attribute_name(field)
          field
        end
      end
    end

    def primary_key
     send(self.class.primary_key)
    end
    
    def ==(other)
     self.class==other.class && self.primary_key==other.primary_key
    end
    
    def ===(other)
     self==other
    end

    def eql?(other)
     self==other
    end
    
    def hash
     self.primary_key.hash
    end
    
    def save!
      save
    end
    
    # Author:: Jon Tirsen, 2006
    # If new_record? returns true it calls the +insert+ statement defined 
    # on this class, otherwise it calls the +update+ statement.
    # Modified by:: Unforgiven.pl
    # updates attributes of current object according to the value returned by the statement
    # is NOT using accessor methods, but directly sets the attributes
    def save      
      res = if new_record? then
             self.class.insert(self)
            else
             self.class.update(self)
            end
      # no updating if the query returned the calling object
      update_from_hash(res || {}) unless res==self
      # no tainted values anymore, unless there was no updating (returned is an empty hash)
      unless res.respond_to?(:empty?) && res.empty?
       @tainted_values=[]
       @new_record=false
      end
      # returning self, so that it is possible to chain many calls - unless there are errors, in which case nil is returned
      self.errors.empty? ? self : nil
    end

    # Author:: Unforgiven.pl
    # modifies contents of the current object by loading them again from the database
    # (fetches the fresh contents from the database)
    # all local changes (tainted columns) and errors made are lost
    def reload
     return nil if @new_record
     res=self.class.reload(self)
     return nil unless res
     @tainted_values=[]
     # update yourself
     update_from_hash(res)
     self.errors.clear
     self
    end

    # Author:: Unforgiven.pl
    def reload!
     reload
    end
    
    # Calls name= with new value.
    def update_attribute(name, value)
      send(name.to_s + '=', value)
      save
    end

    # Author:: Unforgiven.pl
    # updates the contents of the object from hash, keeping those not mentioned in the hash not changed
    # calls setter methods and saves the object to the database, unless "skip save" is true
    def update_attributes(hash, skip_save=false)
     hash.each {|k, v| send(k.to_s+"=", v)}
     skip_save ? self : save
    end
    
    # Called by the RBatis framework when loaded, sets new_record? to false so that #save
    # works properly.
    def on_load
      @new_record = false
    end
    
    def new_record?
      return true if not defined?(@new_record)
      @new_record
    end

    # Author:: Unforgiven.pl
    # attempts to load a class that might be referenced by the missing method
    # (handles automagically has_many and has_and_belongs_to_many)
    def method_missing(name, *params)
      begin
       class_name = name.to_s.camelize.singularize
       # if there is a dependency, a method is created after the dependant class is evaluated
       eval class_name
       # if method created, call it
       if respond_to?(name) then
        send(name, params)
       # otherwise raise anything
       else
        raise "No dependency found."
       end # if
      rescue
       # if there were some errors, method was not found
       raise "Method #{name} not found."
      end # begin/rescue
    end # method_missing

    include ActiveRecord::Validations
    
    private
    # Author:: Unforgiven.pl
    # updates attributes directly, using values from the hash
    def update_from_hash(hash)
     hash.each_key { |attrib| eval("@#{attrib} = hash[attrib]")}
    end
  end
 end
end

UnforgivenPL::RegacyDB::Base.logger = ActiveRecord::Base.logger