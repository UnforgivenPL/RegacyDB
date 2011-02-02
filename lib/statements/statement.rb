require 'sanitizer'
require 'resultmap'

module UnforgivenPL
 module RegacyDB
 
  # Author::    Jon Tirsen, 2006
  class Statement
    attr_accessor :connection_provider
    attr_reader :proc
    attr_accessor :sql
    attr_reader :execution_count
    
    include Sanitizer
    
    def initialize(params, &proc)
      params.each do |k,v|
        setter = "#{k}="
        raise "property #{k} is not supported by statement #{self.class.name}" unless self.respond_to?(setter)
        self.send(setter, v)
      end
      @proc = proc
      reset_statistics
    end
    
    def connection
      connection_provider.connection
    end
    
    # Author:: Unforgiven.pl, 2009
    # Executes the statement. Supports certain conventions to enable handling of statements with method_missing.
    def execute(*args)
      @execution_count += 1
      # if no sql code and no procedure, block is supposed give both
      sql_code = if sql.nil? && proc.nil? then
                  sanitize_sql(yield.flatten)
                 # if procedure was not given, but sql was, block is supposed to give arguments
                 elsif proc.nil? && !sql.nil? then
                  sanitize_sql([sql, yield].flatten)
                 # if sql was not given, but procedure was, procedure is giving both
                 elsif sql.nil? && !proc.nil? then
                  sanitize_sql(proc.call(*args))
                 # otherwise sql contains sql code, and procedure contains arguments
                 else sanitize_sql([sql, proc.call(*args)].flatten)
                 end # if
      puts sql_code if VERBOSE
      result = do_execute(sql_code)
      puts result if VERBOSE
      result
    end
        
    def reset_statistics
      @execution_count = 0
    end
    
    def validate
    end
  end

  class ValidatingStatement < Statement
     attr_reader :resultmap
     def resultmap=(rmap)
      if rmap.is_a?(ResultMap) then
       @resultmap=rmap
      elsif !@resultmap=resultmaps[rmap] then
       @resultmap=resultmaps[:default]
      end
     end
     def validate
      raise 'resultmap has not been specified, you need at least a :defaultmap resultmap declared before the statements' unless resultmap
     end
  end
  
 end
end