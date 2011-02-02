require 'statement'

module UnforgivenPL
 module RegacyDB

  # Author::    Jon Tirsen, 2006
  class SelectValue < Statement
    attr_accessor :result_type
    alias type= result_type=
    
    def do_execute(sql)
      raise "result_type must be specified" unless result_type
      record = connection.select_one(sql)
      return nil unless record
      result_type.from_database(record, record.keys.first)
    end
  end

 end
end