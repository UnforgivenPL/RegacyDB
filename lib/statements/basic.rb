require 'statement'

module UnforgivenPL
 module RegacyDB
 
  # Author::    Jon Tirsen, 2006
  # Modified by:: Unforgiven.pl
  # declaring three classes at once instead of each one separately
  [:insert, :delete, :update].each do |class_name|
   eval <<"DECLARE"
    class #{class_name.to_s.capitalize} < Statement
     def do_execute(sql)
      connection.#{class_name.to_s}(sql)
     end
    end
DECLARE
  end
 
 end
end