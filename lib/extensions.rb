# converts string to fixnum, preserving Infinity
class String
 alias :old_to_f :to_f
 def to_f
  self=~/^[+-]?Infinity$/ ? (self[0].chr=='-' ? -1.0/0 : 1.0/0) : old_to_f
 end
end

# adds support for infinite? in fixnums (never possible)
class Fixnum
 def infinite?
  nil
 end
end

# Converts Fixnum from a database record.
# Author::    Jon Tirsen, 2006
def Fixnum.from_database(record, column)
  record[column].to_i
end

# Converts Float from a database record.
def Float.from_database(record, column)
 record[column].to_f
end

def Fixnum.from_s(string)
 string.to_i
end

def Float.from_s(string)
 string.to_f
end

# Converts String from a database record.
# Author::    Jon Tirsen, 2006
def String.from_database(record, column)
  record[column].to_s
end

# Converts Time from a database record.
def Time.from_database(record, column)
  record[column].nil? ? nil : Time.parse(record[column])
end

