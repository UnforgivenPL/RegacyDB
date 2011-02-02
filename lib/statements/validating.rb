require 'statement'

module UnforgivenPL
 module RegacyDB
 
  # Author:: Unforgiven.pl
  # executes a statement and returns objects according to a resulthashmap
  class Execute < ValidatingStatement
   def do_execute(sql)
    connection.execute(sql).collect {|record| resultmap.map(record)}.uniq
   end
  end # Execute
  
  # Author:: Unforgiven.pl
  # executes a statement, but returns only the first object according to a resulthashmap
  class ExecuteOne < ValidatingStatement
   def do_execute(sql)
    rec=connection.execute(sql)
    return nil if rec.nil? || rec.num_tuples==0
    resultmap.map(rec[0])
   end
  end # ExecuteOne

  # Author:: Unforgiven.pl
  # any custom query - returns an array of hashmaps with results
  # important note: Custom and CustomOne return HASHES instead of OBJECTS!
  # for objects, use Execute and ExecuteOne
  class Custom < ValidatingStatement
   def do_execute(sql)
    query_result=connection.execute(sql)
    result=query_result.collect do |qr|
     single_map={}
     # the magic below remaps the hashmap so that it contains values of proper types, instead of all Strings
     qr.keys.each {|k| (single_map[resultmap.fields[k.to_sym].name]=qr[k].nil? ? nil : resultmap.fields[k.to_sym].type.from_database(qr, k)) if resultmap.fields.has_key?(k.to_sym)}
     single_map
    end
    result
   end
  end

  # Author:: Unforgiven.pl
  # any custom query that returns precisely one result
  # used internally for INSERT RETURNING * and UPDATE RETURNING * statements
  class CustomOne < Custom
   def do_execute(sql)
    super(sql)[0]
   end
  end

  # Author::    Jon Tirsen, 2006
  class Select < ValidatingStatement
    def do_execute(sql)
      connection.select_all(sql).collect{|record| resultmap.map(record)}.uniq
    end
  end

  # Author::    Jon Tirsen, 2006
  # Modified by:: Unforgiven.pl
  # nil is returned when the record contains all nil values
  class SelectOne < ValidatingStatement
    def do_execute(sql)
      record = connection.select_one(sql)
      return nil if record.nil? || record.empty? || record.values.all? {|v| v.nil?}
      resultmap.map(record)
    end
  end

 end
end