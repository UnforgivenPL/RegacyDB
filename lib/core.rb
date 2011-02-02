# RegacyDB - RBatis on Rails 3
# Author::    Miki Olsz (mailto:miki@unforgiven.pl)
# Copyright:: (c) 2009-2011 Unforgiven.pl
# License::   Apache Version 2.0 (see http://www.apache.org/licenses/)
#
# Based on RBatis (where marked)
# Author::    Jon Tirsen  (mailto:jtirsen@apache.org)
# Copyright:: Copyright (c) 2006 Apache Software Foundation
# License::   Apache Version 2.0 (see http://www.apache.org/licenses/)

require 'extensions'

module UnforgivenPL
 module RegacyDB
  VERBOSE = false
  
  class BooleanMapper
    # modified by Unforgiven.pl:
    # support for true/false and t/f values
    def from_database(record, column)
      return nil if record[column].nil?
      return true if (record[column] == '1' || record[column]=='t' || record[column]=='true')
      return false if (record[column] == '0' || record[column]=='f' || record[column]=='false')
      return nil
      #raise "can't parse boolean value for column " + column
    end
  end

  # Author::    Jon Tirsen, 2006
  class Column
    attr_accessor :name
    attr_reader :column
    attr_reader :type

    def initialize(column, type)
      @column = column
      @type = type
    end
    
    def map(record, result)
      result.instance_variable_set("@#{name}".to_sym, value(record))
    end
    
    def value(record)
      type.from_database(record, column)
    end
    
    # Creates a new column mapping with the column name prefixed with +prefix+. Useful when
    # doing eager associations.
    # TODO: not implemented correctly yet.
    def prefix(prefix)  # :nodoc:
      self.class.new(prefix + column, type)
    end
  end
  
  end
end # module RBatis
