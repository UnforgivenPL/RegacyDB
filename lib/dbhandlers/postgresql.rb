module UnforgivenPL
 module RegacyDB
 
  # Author:: Unforgiven.pl
  # translates database error messages to something more human-readable
  class PostgreSQLErrorHandler
    # handler for default constraint errors
    # yields field and message of the error
   def PostgreSQLErrorHandler.handle(klass, message, known_errors={})
    constraint_name = message.scan(/"[a-zA-Z0-9_]+"/).collect {|s| s.delete('"')}
    if constraint_name.nil? || constraint_name.empty? then
     constraint_name = message
    elsif constraint_name.size==1 then
     constraint_name = constraint_name[0]
    else
     constraint_name = constraint_name[1]
    end
    puts "Violated: #{constraint_name}, original: #{message}." if VERBOSE
    # constraints with known error messages
    if known_errors.has_key?(constraint_name) then
     yield nil, known_errors[constraint_name]
    # basic not-null constraints contain only the name of the field
    elsif constraint_name.count("_")==0 then
     yield constraint_name, :empty
    # primary key violations are of the form tablename_pkey
    elsif constraint_name=~/_pkey$/ then
     yield klass.primary_key, :invalid
    # otherwise the fallen constraint has the name table_field_type
    else
     field, type = (constraint_name.sub(klass.table_name+"_","").reverse.split("_",2).collect {|s| s.reverse}.reverse)
     rails_message = case type
      when "fkey" then :invalid
      when "key" then :taken
      when "check" then :invalid
      when "empty" then :empty
      else :invalid
     end # case
     yield field, rails_message
    end # if known_errors
   end # handle
  end # PostgreSQLErrorHandler

 
 end
end