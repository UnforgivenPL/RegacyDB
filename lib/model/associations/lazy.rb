module UnforgivenPL
 module RegacyDB

  # Author::    Jon Tirsen, 2006
  class LazyLoadProxy # :nodoc:
    def initialize(loader, container)
      @loader = loader
      @container = container
    end
    
    def target
      maybe_load
      @target
    end
    
    def method_missing(name, *args, &proc)
      self.target.send(name, *args, &proc)
    end
    
    def to_s
      self.target.to_s
    end
    
    private
    
    def maybe_load
      @target = load if !defined?(@target)
    end
    
    def load
      @loader.load(@container)
    end
  end

  # Author::    Jon Tirsen, 2006
  class LazyAssociation
    attr_accessor :name

    def initialize(options={}, &loader)
      @options = options
      @options[:keys] = @options[:keys] || [@options[:key]]
      @loader = loader
    end
    
    def map(record, result)
      # association has already been loaded, don't overwrite with proxy
      return if result.instance_variable_get("@#{name}".to_sym)
      
      result.instance_variable_set("@#{name}".to_sym, LazyLoadProxy.new(self, result))
    end
    
    def load(container)
      return @loader.call if @loader
      
      keys = @options[:keys].collect{|key| container.instance_variable_get("@#{key}".to_sym)}
      @options[:to].send(@options[:select], *keys)
    end
  end

 end
end