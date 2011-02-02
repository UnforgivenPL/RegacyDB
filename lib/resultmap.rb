module UnforgivenPL
 module RegacyDB

  # Author::    Jon Tirsen, 2006
  class ResultMap
    attr_reader :fields
    attr_reader :factory
    
    def initialize(factory, fields)
      @factory = factory
      @fields = {}
      fields.each { |name, field_spec|  self[name]=field_spec }
    end

    # Author:: Unforgiven.pl
    # adds or changes the field mapping type when the resultmap is already made
    def []=(name, field_spec)
        if field_spec.is_a?(Array)
          raise 'column name and type must be specified' unless field_spec.size >= 2
          @fields[name] = Column.new(*field_spec)
        else
          @fields[name] = Column.new(name,field_spec)
        end
        @fields[name].name = name
    end
    
    # Author::    Jon Tirsen, 2006
    # Modified by:: Unforgiven.pl
    def map(record)
      result=hydrate(factory.get_or_allocate(self, record), record)
      # setting tainted values to none on automatic read
      result.instance_variable_set(:@tainted_values,[])
      result
    end
    
    def hydrate(result, record)
      fields.each_value{|f| f.map(record, result)}
      result.on_load if result.respond_to?(:on_load)
      result
    end
    
    def value_of(name, record)
      fields[name].value(record)
    end
    
    # Creates a new ResultMap that is identical to the previous one
    # except that all columns are prefixed with the specified +prefix+.
    # Use with EagerAssociation to fetch associated items from an OUTER JOIN fetch
    # to accomplish eager loading and avoiding the N+1 select problem.
    # TODO: Not implemented correctly yet.
    def prefix(prefix) # :nodoc:
      ResultMap.new(factory, fields.collect{|n,f| [n, f.prefix(prefix)]})
    end
    
    # Creates a new ResultMap containing all the same fields except those overriden
    # by +fields+.
    def extend(overriding_fields)
      ResultMap.new(factory, fields.merge(overriding_fields))
    end
    
    def all_nil?(record)
      fields.each_value{|f| return false if !f.value(record).nil?}
      return true
    end
  end

 end
end