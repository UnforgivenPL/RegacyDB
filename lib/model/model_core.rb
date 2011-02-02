require 'associations/eager'
require 'associations/lazy'
require 'dbhandlers/postgresql'

module UnforgivenPL
 module RegacyDB

  # Author::    Jon Tirsen, 2006
  module ModelCore
    
    # Author::    Jon Tirsen, 2006
    # Modified by:: Unforgiven.pl
    def self.included(included_into)
      # this is called when included into RBatis::Base (JT)
      included_into.instance_variable_set(:@resultmaps, {})
      included_into.instance_variable_set(:@statements, {})
      # added by Unforgiven.pl
      # name of the table
      included_into.instance_variable_set(:@table_name, nil)
      # name and type of the primary key
      included_into.instance_variable_set(:@pk_name,    "id")
      included_into.instance_variable_set(:@pk_type,  Fixnum)
      # error messages (constraint => message)
      included_into.instance_variable_set(:@error_msgs, {})
      # adds class methods (JT)
      class <<included_into        
        include ClassMethods
      end
    end
    
    # Author::    Jon Tirsen, 2006
    module ClassMethods
      def statements
        @statements
      end
      
      alias selects statements # :nodoc:
      alias inserts statements # :nodoc:
      alias updates statements # :nodoc:
      
      # Returns Hash of all #resultmaps defined by #resultmap.
      def resultmaps
        @resultmaps
      end

      # Author:: Unforgiven.pl
      # Returns name of the table, by default it is class name in plural, lowercase, separated with _
      def table_name
       @table_name = self.name.underscore.pluralize if @table_name.nil?
       @table_name
      end

      # Author:: Unforgiven.pl
      # sets the name of the table
      def set_table_name(name)
       @table_name = name.to_s
      end

      # Author:: Unforgiven.pl
      # returns name of the primary key, defaults to "id"
      def primary_key
       @pk_name
      end
      
      # Author:: Unforgiven.pl
      # returns type of the primary key, defaults to Fixnum
      def primary_key_type
       @pk_type
      end
      
      # Author:: Unforgiven.pl
      # sets the name of the primary key
      def set_primary_key(name, pktype=Fixnum)
       attribute(name, pktype) unless name.to_s=="id"
       @pk_name = name.to_s
       @pk_type = pktype
      end

      # Specify which class this Core maps to.
      def maps(cls)
        @maps = cls
      end
      
      # Returns the mapped_class (specified with #maps) or +self+ if not specified.
      def mapped_class
        @maps || self
      end
      
      # Returns a BooleanMapper, useful for #resultmaps like this:
      #   resultmap :default,
      #     :username => ['userid', String],
      #     :email_offers => ['offersopt', boolean],
      def boolean
        BooleanMapper.new
      end
      
      def association(type, *args)
        type = case type
          when Class then type
          when :lazy then LazyAssociation
          when :eager then raise 'eager associations not yet implemented'
        end
        type.new(*args)
      end
      
      def get_or_allocate(recordmap, record) # :nodoc:
        mapped_class.allocate
      end
      
      # Defines a named ResultMap which is a map from field name to mapping specification.
      # For example:
      #   resultmap :default,
      #     :username => ['userid', String],
      #     :email => ['email', String],
      #     :first_name => ['firstname', String],
      #     :last_name => ['lastname', String],
      #     :address1 => ['addr1', String],
      #     :address2 => ['addr2', String],
      #     :city => ['city', String],
      #     :state => ['state', String],
      #     :zip => ['zip', String],
      #     :country => ['country', String],
      #     :phone => ['phone', String],
      #     :favourite_category_name => ['favcategory', String],
      #     :language_preference => ['langpref', String],
      #     :list_option => ['mylistopt', boolean],
      #     :banner_option => ['banneropt', boolean],
      #     :banner => RBatis::LazyAssociation.new(:to => Banner, 
      #                                           :select => :find_by_favcategory,
      #                                           :key => :favourite_category_name),
      #     :favourite_category => RBatis::LazyAssociation.new(:to => Category, 
      #                                                       :select => :find_by_name,
      #                                                       :key => :favourite_category_name)
      #
      def resultmap(name = :default, fields = {})
        resultmaps[name] = ResultMap.new(self, fields)
      end

      # Useful for eager loading.
      # TODO not implemented properly yet.
      def extend_resultmap(name, base, fields) # :nodoc:
        resultmaps[name] = base.extend(fields)
      end
      
      # Instantiates the statement and puts it into #statements also generates a class method with the same name that invokes the statement. For example:
      #
      #   class Product < RBatis::Base
      #     statement :select_one, :find do |productid|
  		#   	  ["SELECT * FROM product WHERE productid = ?", productid]
  		#     end
  		#   end
  		#
  		# Can be invoked with:
  		#   Product.select_one(id)
  		#
  		# Note: This also needs a +resultmap+ named +:default+:
      #  
      # +statement_type+ is one of:
      # :select:: Selects and maps multiple object (see Select)
      # :select_one:: Selects and maps one object (see SelectOne)
      # :select_value:: Selects a single value such as an integer or a string (see SelectValue)
      # :insert:: Inserts new records into the database (see Insert)
      # :update:: Updates the database (see Update)
      # :delete:: Deletes records from the database (see Delete)
      #
      # Modified by:: Unforgiven.pl
      # Simplified handling the type of the statement.
      def statement(statement_type, name = statement_type, params = {}, &proc)
        statement_type = eval(statement_type.to_s.camelize) unless statement_type.respond_to?(:new)
        statement = statement_type.new(params, &proc)
        statement.connection_provider = self
        statement.resultmap = resultmaps[:default] if statement.respond_to?(:resultmap=) && statement.resultmap.nil?
        statement.validate
        statements[name.to_sym] = statement
        puts "Declared statement #{name} in #{self.to_s}" if VERBOSE
        # statements are executed in method_missing
      end

      # Creates a new instance of mapped_class.
      def create(*args, &proc)
        mapped_class.new(*args, &proc)
      end
      
      def reset_statistics # :nodoc:
        selects.each_value{|s| s.reset_statistics}
      end
      
      # Author:: Unforgiven.pl
      # associates constraint names with an error_message
      def constraint_error(constraint, message)
       @error_msgs[constraint]=message
      end
      
      # Author:: Unforgiven.pl
      # sets messages for constraint errors (named constraints)
      def constraint_errors(errors={})
       @error_msgs=errors
      end
      
      # Author:: Unforgiven.pl
      # makes a reference from current table to another one (model)
      # by default, also, the model class is updated to contain a reference "back"
      # can be used in attributes (with :reference as type, if following conventions)
      # can also be used alone
      # supported options are:
      #  :fkey      - name of the referenced column in the model (defaults to model's primary key)
      #  :fkey_type - type of the referenced column in the model (defaults to model's primary key type)
      #  :field     - name of the method in the class that returns the value of the referenced column (defaults to model's table name joined with :fkey)
      #  :column    - name of the column in the table of the model (defaults to :field)
      #  :method    - name of the method in the class that returns the referenced object (defaults to model's table name singular)
      #  :link_back - name of the method in the model that will serve as the other end of the relation, or :none if no link back needed
      def belongs_to(model, options={})
       # model can be a symbol, instead of class name
       model=eval(model.to_s.capitalize) if model.is_a?(Symbol)
       # foreign key (a column in the table the reference points to)
       options[:fkey] = model.primary_key unless options.has_key?(:fkey)
       options[:fkey_type] = model.primary_key_type unless options.has_key?(:fkey_type)
       # field in current table that corresponds to the other table
       options[:field] = model.table_name.singularize+"_"+options[:fkey] unless options.has_key?(:field)
       # the name of the db column
       options[:column] = options[:field] unless options.has_key?(:column)
       # the name of method that returns the object itself, not only the id (defaults to referenced table name)
       options[:method] = model.table_name.downcase.singularize unless options.has_key?(:method)
       # local methods - :field for obtaining and assigning the id, :method for obtaining the object
       # :field
       # reader is farly easy
       attr_reader options[:field]
       # writer takes an argument
       define_method "#{options[:field]}=" do |value|
        if value.is_a?(options[:fkey_type]) then
         eval "@#{options[:field]}=value"  # set the id only (object will be loaded when accessed)
         #eval "@#{options[:method]}=nil"    # clear the stored object
        # special case, a key type may respond to "from_s"
        elsif options[:fkey_type].respond_to?(:from_s) then
         eval "@#{options[:field]}=#{options[:fkey_type]}.from_s(value)"
        else
         eval "@#{options[:field]}=value.send(options[:fkey])" # set the id
         eval "@#{options[:method]}=value"                     # set the object (directly)
        end # if
        taint_field(options[:field])
       end
       # update result map
       update_result_map(options[:field], options[:column], options[:fkey_type])
       # :method
       # reader is quite easy
       define_method options[:method] do
        current_id=eval "@#{options[:field]}" # currently stored id
        current=eval "@#{options[:method]}"   # currently stored object
        # reload object with fresh copy when not nil and either not stored or stored different
        # TODO: find_by_fkey!!!
        eval("@#{options[:method]}=model.find(#{current_id})") if !current_id.nil? && (current.nil? || current.send(options[:fkey])!=current_id)
        eval "@#{options[:method]}" # return value of the attribute
       end # define method
       # writer is also easy, it sets also the corresponding :field with :fkey value of the object
       define_method "#{options[:method]}=" do |value|
        eval "@#{options[:method]}=value" # set the object
        eval "@#{options[:field]}=value.send(options[:fkey])" # set the value
        taint_field(options[:field]) # the field (blah_id) is marked as tainted
       end # define method
       # now updating the target class with link_back methods
       options[:link_back]=self.table_name # by default is the name of the table
       # link_back calls has_many on the target class, using the name of method provided with the :link_back
       model.has_many(self,:method=>options[:link_back],:column=>options[:column]) if options[:link_back] && options[:link_back]!=:none
      end

      # Author:: Unforgiven.pl
      # opposite end of belongs_to; calls model's find_by_:column
      # supported options are:
      #  :method - name of the method (defaults to model's table name)
      #  :column - name of the column in the model to look values for (defaults to table name singularised joined with primary key)
      def has_many(model, options={})
       # model can be given as a symbol like :users
       model=eval(model.to_s.singularize.camelize) unless model.respond_to?(:table_name)
       # default name of the method is the name of the table in the model
       options[:method]=model.table_name.downcase unless options.has_key?(:method)
       # default column is singularised current table name with _ and self primary key name
       options[:column]=self.table_name.downcase.singularize+"_"+self.primary_key unless options.has_key?(:column)
       # a method corresponds to target model's find_by_column(id)
       # the results are returned only when they are called
       define_method options[:method] do
        model.send("find_by_#{options[:column]}",send(self.class.primary_key))
       end
      end # has_many

      # Author:: Unforgiven.pl
      # creates a many-to-many relationship between two models with the use of a link table (NOT model)
      # supported options:
      #  :through   - name of the link table (defaults to model's table name singularised joined with this table name)
      #  :to_model  - name of the column in the :through table that references the model's table (defaults to model's table name singularised joined with model's primary key)
      #  :to_this   - name of the column in the :through table that references this table (defaults to this table name singularised joined with this primary key)
      #  :method    - name of the method to return referenced objects (defaults to model's table name)
      #  :link_back - name of the method to be created in the model (defaults to this table name) or :none, if no link_back (node: no link back is created if the method is already defined in the model!)
      def has_and_belongs_to_many(model, options={})
       # model can be given as a symbol
       model=eval(model.to_s.singularize.camelize) unless model.respond_to?(:table_name)
       # default name of the "through" table is (model.table_name.singularize_self.table_name
       options[:through]=model.table_name.singularize+"_"+self.table_name unless options.has_key?(:through)
       # default name of the "to_model" field is model.table_name.singularize_model.primary_key
       # same applies to "to_this"
       {:to_model=>model,:to_this=>self}.each {|k, v| options[k]=v.table_name.downcase.singularize+"_"+v.primary_key unless options.has_key?(v)}
       # method name is same as the model's table_name
       options[:method]=model.table_name.downcase unless options.has_key?(:method)
       # a statement that returns related model instances
       # basically those whose primary_key is contained in the through table
       statement(:select, options[:method], :resultmap=>model.resultmaps[:default]) do |this_id|
        ["SELECT #{model.table_name}.* FROM #{options[:through]} JOIN #{model.table_name} ON #{options[:through]}.#{options[:to_model]}=#{model.table_name}.#{model.primary_key} WHERE #{options[:through]}.#{options[:to_this]}=?",this_id]
       end # statement
       define_method options[:method] do
        self.class.send(options[:method], send(self.class.primary_key))
       end # define_method
       # make a link back to self if not yet made
       options[:link_back]=self.table_name.downcase unless options.has_key?(:link_back)
       model.has_and_belongs_to_many(self, :through=>options[:through], :to_model=>options[:to_this], :to_this=>options[:to_model], :method=>options[:link_back], :link_back=>:none) unless options[:link_back]==:none || self.instance_methods.include?(options[:link_back].to_s)
      end # has_and_belongs_to_many

      # Author:: Unforgiven.pl
      # updates default resultmap to contain a field, column and its type
      def update_result_map(field, column, fieldtype)
        resultmap(:default, {}) unless resultmaps.has_key?(:default)
        resultmaps[:default][field.to_sym]=[column.to_s, fieldtype]
      end
      private :update_result_map

      # Author:: Unforgiven.pl
      # declares an attribute
      # field - name of the field (model)
      # fieldtype - type of the field, nil for virtual fields (non-database)
      # column - name of the column in the database (defaults to the name of the field)
      def attribute(field, fieldtype=nil, column=field)
       if fieldtype.nil? then
        attr_accessor field
       else
        # regular reader
        attr_reader field
        # writer sets that the field is tainted
        # this does not apply to primary key, which cannot be changed
        unless field.to_s==primary_key.to_s
          define_method "#{field}=" do |value|
           eval "@#{field}=value"
           taint_field(field)
          end # define_method
        end # unless
        # update default resultmap
        update_result_map(field, column, fieldtype)
       end # if
      end
      
      # Author:: Unforgiven.pl
      # all-in-one wrapping for the construction of attributes and statements
      # definitions is a hashmap that maps fields and their values and other properties:
      #  :column_name => type / :virtual / :reference
      # Virtual columns are neither saved into nor read from the database.
      # References must follow naming conventions to be created this way. Otherwise use belongs_to.
      def attributes(fields={})
       fields[primary_key]=primary_key_type unless fields.has_key?(primary_key)
       resmaphash={}
       fields.each_key do |field|
        case fields[field]
         when :virtual
          # virtual fields have the reader, and writer, and nothing else
          attribute field
         when :reference
          # references are a little tricky
          # indicating a reference in attributes means that the db follows naming patterns
          # (otherwise references can be added with a belongs_to method)
          # obtaining ftable and fkey
          ftable, fkey = field.to_s.reverse.split("_",2).reverse.collect {|c| c.reverse}
          # calling reference maker
          belongs_to ftable.to_sym, :field=>field, :fkey=>fkey
         else
          attribute field, fields[field]
        end # case (type of field)
       end # each field
       # typical statements are handled by method_missing
       # unless redefined with "statement"
      end
      
      # Author:: Unforgiven.pl
      # captures calls on missing methods to produce and execute statements during run-time
      def method_missing(name, *params)
       name=name.to_sym
       # if there is no pre-made statement of the called name...
       if statements[name].nil? then
        # ...make it
        data = method_name_to_statement_data(name, params) {|p| params=p}
        # raising exception if data is nil
        raise "Method #{name} not found." if data.nil?
        # returning first passed param when returned no query
        return params[0] if data.empty?
        # otherwise saving the statement
        puts "Query:  "+data[1].inspect if VERBOSE
        # statement created with sql and without procedure will yield for query parameters at execution
        statement = data[0].new({:sql=>data[1]})
        statement.connection_provider=self
        statement.resultmap = resultmaps[:default] if statement.respond_to?(:resultmap=) && statement.resultmap.nil?
        statement.validate
        statements[name]=statement
       end
       # here, means that there IS a statement of the given name
       begin
        statements[name].execute(*params) {method_name_to_runtime_params(name, params)}
       rescue ActiveRecord::StatementInvalid => invalid
        #perform error handling
        (eval self.connection.adapter_name+"ErrorHandler").handle(self, invalid.message, @error_msgs, &method_name_to_error_handling_block(name, params))
         # now, the {} must be returned so that the state of the object is not updated
        {}
       end # rescue
      end  # method missing
      
      # rails trickery so that error messages work as expected
      # taken from http://manalang.com/bdoc/rdoc/authlogic-2.0.3/rdoc/classes/Authlogic/Session/ActiveRecordTrickery/ClassMethods.html
      # rails >= 2.3
      def self_and_descendants_from_active_record
       return [self]
      end
      
      # rails trickery so that error messages work as expected
      # rails < 2.3 had a spelling error in the method name :)
      def self_and_descendents_from_active_record
       self_and_descendants_from_active_record
      end
      
      # rails trickery so that error messages work as expected
      # taken from http://manalang.com/bdoc/rdoc/authlogic-2.0.3/rdoc/classes/Authlogic/Session/ActiveRecordTrickery/ClassMethods.html
      # makes a human name
      def human_name(*args)
       I18n.t("models.#{name.underscore}", {:count=>1, :default=>name.humanize})
      end

      private
      
      # Author:: Unforgiven.pl
      # constructs a statement for a method name
      def method_name_to_statement_data(name, params)
       case name.to_s
        # default, pre-made statements
        when "find"
         [SelectOne, "SELECT * FROM #{table_name} WHERE #{primary_key} = ?"]
        when "find_all"
         [Select, "SELECT * FROM #{table_name}"]
        when /find_(first_)?by_([a-z0-9_]+?)_(and|or)_([a-z0-9_]+)/
         [$1.nil? ? Select : SelectOne, "SELECT * FROM #{table_name} WHERE #{$2} = ? #{$3} #{$4} = ?"]
#        when /find_by_([a-z0-9_]+?)_or_([a-z0-9_]+)/
#         [Select, "SELECT * FROM #{table_name} WHERE #{$1} = ? OR #{$2} = ?"]
        when /find_(first_)?by_([a-z0-9_]+)/
         [$1.nil? ? Select : SelectOne, "SELECT * FROM #{table_name} WHERE #{$2} = ?"]
        when "insert"
         [CustomOne] # the query is constructed upon execution, based on tainted values
        when "update"
         [CustomOne] # the query is constructed upon execution, based on tainted values
        when "delete"
         [Delete, "DELETE FROM #{table_name} WHERE #{primary_key} = ?"]
        when "reload"
         [CustomOne, "SELECT * FROM #{table_name} WHERE #{primary_key} = ?"] # note a subtle difference between find and reload
        else # case
         nil
       end # case
      end

      # Author:: Unforgiven.pl
      # handles the parameters on runtime
      def method_name_to_runtime_params(name, params)
       case name.to_s
        when /(insert|update)/
         model=params[0]
         tainted=model.instance_variable_get("@tainted_values")
         if tainted.nil? || tainted.empty? then
          []
         else
          result=tainted.collect {|t| model.send(t)}
          if $1=="insert" then
           result.insert(0, "INSERT INTO #{table_name} (#{tainted.join(', ')}) VALUES (#{(['?']*tainted.size).join(', ')}) RETURNING *")
          else
           result.insert(0, "UPDATE #{table_name} SET #{tainted.collect {|t| t+' = ?'}.join(', ')} WHERE #{primary_key} = ? RETURNING *").push(model.send("#{primary_key}"))
          end # if insert/update
         end # if tainted.nil? or empty?
        when "reload"
         params[0].send("#{primary_key}")
        else
         params
       end # case
      end  # method name to runtime params
      
      # Author:: Unforgiven.pl
      # returns error handling block based on the method name and params
      def method_name_to_error_handling_block(name, params)
       # if params are in an non-empty array, whose first element responds to errors, and errors of such respond to add_to_base and add...
       if params.is_a?(Array) && !params.empty? && params[0].respond_to?(:errors) && params[0].errors.respond_to?(:add_to_base) && params[0].errors.respond_to?(:add) then
         # the block simply adds the error message to that object
         Proc.new {|field, msg| field.nil? ? params[0].add_to_base(msg) : params[0].errors.add(field, msg)}
       # otherwise...
       else
         # error message is raised
         Proc.new {|field, msg| raise(field.nil? ? msg.to_s : field.to_s+": "+msg.to_s)}
       end # if
      end # def

    end # module class methods
  end # module Core


 end
end