=begin

Permission to use, copy, modify, and distribute this software for
any purpose and without fee is hereby granted, provided that the above
copyright notice appear in all copies.

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

Name:         Translate.rb
Author:       Andreas Eisenbarth
Description:  Class to store and retrieve options/settings.
              Options can only be of a JSON compatible class (no subclasses currently).
              Options preserve their class (a value that was initialized as string cannot be changed into Fixnum).
Usage:        Create an instance:        @options = @options.new(default={key => value})
              Get an option:             @options[String||Symbol]
              Get an option and provide default (if not yet set in initialization):
                                         @options[String||Symbol, default]
              Set an option:             @options[String||Symbol]=(value)
              Get all options:           @options.get_all()
              Update all options:        @options.update(new_options={key => value})
              Get all options as json:   @options.get_json()
              Update all options:        @options.update_json(String)
              Save all options to disk:  @options.save
              Reset to original state  : @options.reset
Version:      1.0.2
Date:         02.04.2013

=end

module AE



module LaunchUp



class Options



@@valid_types = [String, Symbol, Fixnum, Float, Array, Hash, TrueClass, FalseClass, NilClass]

# Create a new instance and fill it with saved options or a provided defaults.
# @param [String] identifier
# @param [Hash] default options
def initialize(identifier, default={})
  raise(ArgumentError, "Argument 'identifier' must be a String argument to identify the option.") unless identifier.is_a?(String)
  raise(ArgumentError, "Optional argument 'default' must be a Hash.") unless default.nil? || default.is_a?(Hash)
  @identifier = identifier
  @default = Marshal.dump(default) # Allows later to create deep copies.
  @options = default
  self.update(read())
end



# Get a value for a key.
# @param [Symbol] key
# @param [Object] default if key is not found
# @returns [Object] value with a type of @@valid_types
def get(key, default=nil)
  raise(ArgumentError, "Argument 'key' must be a String or Symbol.") unless key.is_a?(String) || key.is_a?(Symbol)
  # Alternative ways can be implemented here. (reading individual registry keys etc.)
  key = key.to_sym unless key.is_a?(Symbol)
  return (@options.include?(key)) ? @options[key] : default
end
alias_method(:[], :get)



# Set a value for a key.
# @param [Symbol] key
# @param [Object] value with a type of @@valid_types
def set(key, value)
  raise(ArgumentError, "Argument 'key' must be a String or Symbol.") unless key.is_a?(String) || key.is_a?(Symbol)
  raise(ArgumentError, "Not a valid type for Options.[]=") unless @@valid_types.include?(value.class)
  self.update({key => value})
end
alias_method(:[]=, :set)



# Returns all options as a Hash.
def get_all
  return @options.clone
end



# Updates all options with new ones (overwriting or adding to existing key/value pairs).
# @param [Hash] hash of new data to be merged
def update(hash)
  raise(ArgumentError, "Argument 'hash' must be a Hash.") unless hash.is_a?(Hash)
  normalize_keys(hash)
  @options.merge!(hash){|key, oldval, newval|
    newval = newval.to_sym if oldval.class == Symbol && newval.class == String
    # Accept all new values
    (!@options.include?(key) ||
    # Accept updated values only if they have the same type as the old value.
    # Do a special test for Boolean which consists in Ruby of two classes (TrueClass != FalseClass).
    @@valid_types.include?(newval.class) &&
    (newval.class == oldval.class || oldval == true && newval == false || oldval == false && newval == true)) ?
    newval : oldval
  }
end



# Returns all options as JSON string.
# @returns [String] JSON data
def get_json
  return to_json()
end



# Updates all options with new ones from a JSON string.
# @param [String] string of JSON data
def update_json(string)
  raise(ArgumentError, "Argument 'string' must be a String.") unless string.is_a?(String)
  hash = from_json(string)
  self.update(hash)
end



# Saves the options to disk.
# TODO: Alternatively this could be implemented to save everytime a single
# key/value pair is changed.
def save
  # Alternative ways can be implemented here. (text file etc.)
  # TODO: Handle Unicode and special characters.
  # (If further escaping than inspect is necessary.)
  Sketchup.write_default("Plugins_ae", @identifier, @options.inspect.gsub(/"/, "'"))
  # Sketchup.write_default("Plugins_ae", @identifier, @options.inspect.inspect[1..-2]) # TODO!!!
end



# Resets the options to the plugin's original state.
# This is useful to get rid of corrupted options and prevent saving and reloading them to the registry.
def reset
  @options = Marshal.load(@default)
end



# Reads the options from disk.
def read
  # Alternative ways can be implemented here. (text file etc.)
  default = eval(Sketchup.read_default("Plugins_ae", @identifier, "{}"))
  return (default.is_a?(Hash)) ? default : {}
rescue
  return {}
end
private :read



# Remove all keys whose value is not allowed. Set all keys to Symbols.
# Remove all keys that are neither Symbol nor String.
# @TODO: Or maybe tolerate Fixnum?
# @param [Hash] hash
def normalize_keys(hash)
  hash.each{|k, v|
    hash.delete(k) unless @@valid_types.include?(v.class)
    if k.is_a?(String)
      hash.delete(k)
      hash[k.gsub(/\-/, "_").to_sym] = v
    elsif !k.is_a?(Symbol) # elsunless
      hash.delete(k)
    end
  }
  return hash
end
private :normalize_keys



# Return the options as JSON string.
# TODO: consider Infinity
def to_json
  obj = @options.clone
  # Remove non-JSON objects.
  obj.reject!{|k,v|
    !k.is_a?(String) && !k.is_a?(Symbol) || !@@valid_types.include?(v.class)
  }
  # Split at every even number of unescaped quotes. This gives either strings
  # or what is between strings.
  # If it's not a string then turn Symbols into String and replace => and nil.
  json_string = obj.inspect.split(/(\"(?:.*?[^\\])*?\")/).
    collect{|s|
      (s[0..0] != '"') ?                       # If we are not inside a string
      s.gsub(/\:(\S+?(?=\=>|\s|,|\}))/, "\"\\1\""). # Symbols to String
        gsub(/\=\>/, ":").                     # Arrow to colon
        gsub(/\bnil\b/, "null") :              # nil to null
      s                                        # If it's a string don't touch it.
    }.join
  return json_string
end



# Read a JSON string and return a hash.
# @param [String] json_string
# TODO: undefined is not allowed to occur, but in case it happens not sure what to do?
def from_json(json_string)
  raise(ArgumentError, "Argument 'json_string' must be a String.") unless json_string.is_a?(String)
  # Split at every even number of unescaped quotes.
  # If it's not a string then replace : and null
  ruby_string = json_string.split(/(\"(?:.*?[^\\])*?\")/).
    collect{|s|
      (s[0..0] != '"')? s.gsub(/\:/, "=>").gsub(/null/, "nil").gsub(/undefined/, "nil") : s
    }.
    join()
  result = eval(ruby_string)
  return result
rescue Exception
  {}
end
private :from_json



end # class Options



end # module LaunchUp



end # module AE
