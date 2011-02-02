module UnforgivenPL
 module RegacyDB

  # Implements loading of eager outer join associations.
  # Author::    Jon Tirsen, 2006
  # TODO: Not implemented correctly yet.
  class EagerAssociation # :nodoc:
    attr_accessor :name
    attr_reader :resultmap
    
    def initialize(resultmap)
      @resultmap = resultmap
    end
    
    def map(record, result)
      ary = result.instance_variable_get("@#{name}".to_sym)
      ary = [] if ary.nil?
      ary << resultmap.map(record) unless resultmap.all_nil?(record)
      result.instance_variable_set("@#{name}".to_sym, ary)
    end
  end

 end
end