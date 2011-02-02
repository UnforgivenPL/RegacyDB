# SQL query sanitiser.
# 
# Author::    Jon Tirsen  (mailto:jtirsen@apache.org)
# Copyright:: Copyright (c) 2006 Apache Software Foundation
# License::   Apache Version 2.0 (see http://www.apache.org/licenses/)

module UnforgivenPL
 module RegacyDB
  module Sanitizer
    # Accepts an array or string.  The string is returned untouched, but the array has each value
    # sanitized and interpolated into the sql statement.
    #   ["name='%s' and group_id='%s'", "foo'bar", 4]  returns  "name='foo''bar' and group_id='4'"
    def sanitize_sql(ary)
      return ary unless ary.is_a?(Array) && !ary.empty?
      statement, *values = ary
      if values.first.is_a?(Hash) and statement =~ /:\w+/
        replace_named_bind_variables(statement, values.first)
      elsif statement.include?('?')
        replace_bind_variables(statement, values)
      else
        statement % values.collect { |value| connection.quote_string(value.to_s) }
      end
    end

    module_function :sanitize_sql

    def replace_bind_variables(statement, values)
      raise_if_bind_arity_mismatch(statement, statement.count('?'), values.size)
      bound = values.dup
      statement.gsub('?') { quote_bound_value(bound.shift) }
    end

    def replace_named_bind_variables(statement, bind_vars)
      raise_if_bind_arity_mismatch(statement, statement.scan(/:(\w+)/).uniq.size, bind_vars.size)
      statement.gsub(/:(\w+)/) do
        match = $1.to_sym
        if bind_vars.has_key?(match)
          quote_bound_value(bind_vars[match])
        else
          raise PreparedStatementInvalid, "missing value for: #{match} in #{statement}"
        end
      end
    end

    def quote_bound_value(value)
      case value
        when Array
          value.map { |v| connection.quote(v) }.join(',')
        else
          connection.quote(value)
      end
    end

    def raise_if_bind_arity_mismatch(statement, expected, provided)
      unless expected == provided
        raise PreparedStatementInvalid, "wrong number of bind variables (#{provided} for #{expected}) in: #{statement}"
      end
    end

    def extract_options_from_args!(args)
      if args.last.is_a?(Hash) then args.pop else {} end
    end

    def encode_quoted_value(value)
      quoted_value = connection.quote(value)
      quoted_value = "'#{quoted_value[1..-2].gsub(/\'/, "\\\\'")}'" if quoted_value.include?("\\\'")          
      quoted_value
    end
  end
 end
end