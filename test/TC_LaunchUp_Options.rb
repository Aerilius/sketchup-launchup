require 'sketchup.rb'
require 'test/unit'



class TC_LaunchUp_Options < Test::Unit::TestCase



def setup
end



def teardown
  # Empty the registry entry (we can't delete it)
  Sketchup.write_default("Plugins_ae", "test", "")
end



def test_initialize
  # Requires one argument, accepts at least two arguments.
  arity = AE::LaunchUp::Options.instance_method(:initialize).arity
  min_arity = 1
  max_arity = 2
  assert(arity >= max_arity || arity == -min_arity-1, "Options.initialize should requires one argument and accept at least two arguments.")
  # The first must be a string as identifier.
  assert_nothing_raised("Options.initialize: first argument should accept a string.") { AE::LaunchUp::Options.new("test") }
  assert_raise(ArgumentError, "Options.initialize: first argument should only accept a string.") { AE::LaunchUp::Options.new(42) }
  assert_raise(ArgumentError, "Options.initialize: first argument should only accept a string.") { AE::LaunchUp::Options.new(3.14) }
  assert_raise(ArgumentError, "Options.initialize: first argument should only accept a string.") { AE::LaunchUp::Options.new(Object.new) }
  # The second must be a hash.
  assert_nothing_raised("Options.initialize: second argument should accept a hash.") { AE::LaunchUp::Options.new("test", {}) }
  assert_raise(ArgumentError, "Options.initialize: second argument should only accept a hash.") { AE::LaunchUp::Options.new("test", "") }
  assert_raise(ArgumentError, "Options.initialize: second argument should only accept a hash.") { AE::LaunchUp::Options.new("test", 42) }
  assert_raise(ArgumentError, "Options.initialize: second argument should only accept a hash.") { AE::LaunchUp::Options.new("test", 3.14) }
  assert_raise(ArgumentError, "Options.initialize: second argument should only accept a hash.") { AE::LaunchUp::Options.new("test", Object.new) }
  # It creates a registry value under Plugins_ae with the first argument as name.
  value = Sketchup.read_default("Plugins_ae", "test", false)
  assert(value != false, "Options.initialize should create a registry key under Plugins_ae with the first argument as name.")
  # It should only read existing keys from the registry if it is valid.
  reg = "{:key1 => 'String', :key2 => :Symbol, :key3 => 42, :key4 => 3.14, :key5 => -2.78, :key6 => nil, :key7 => true, :key8 => false, :key9 => [1,2,3], :key10 => {:key11 => 'string2'}, 'key11' => 'String', 'key12' => :Symbol, 'key13' => 42, 'key14' => 3.14, 'key15' => -2.78, 'key16' => nil, 'key17' => true, 'key18' => false, 'key19' => [1,2,3], 'key20' => {'key21' => 'string2'}, 71 => 'String', 1.618 => :Symbol, Object.new => 42, Kernel => 3.14, Proc.new{} => -2.78, Time.now => nil, Regexp.new('') => true, (1..2) => false, nil => [1,2,3], false => {:key11 => 'string2'}, :key21 => Object.new, :key22 => Kernel, :key23 => Proc.new{}, :key24 => Time.now, :key25 => Regexp.new(''), :key26 => (1..2)}"
  #reg = "{false=>{:key11=>'string2'}, //=>true, 71=>'String', 'key20'=>{'key21'=>'string2'}, 'key19'=>[1, 2, 3], :key7=>true, :key2=>:Symbol, :key22=>Kernel, 1.618=>:Symbol, 'key11'=>'String', :key8=>false, 1..2=>false, nil=>[1, 2, 3], 'key12'=>:Symbol, :key9=>[1, 2, 3], :key3=>42, 'key13'=>42, Kernel=>3.14, 'key14'=>3.14, :key10=>{:key11=>'string2'}, :key4=>3.14, :key25=>//, 'key15'=>-2.78, 'key16'=>nil, :key5=>-2.78, :key26=>1..2, 'key17'=>true, :key6=>nil, :key1=>'String', 'key18'=>false}"
  Sketchup.write_default("Plugins_ae", "test", reg)
  options = AE::LaunchUp::Options.new("test")
  assert( options.get_all.length == 20, "It should only read existing keys from the registry if they are valid.")
  # It should not read existing keys from the registry that are invalid.
  Sketchup.write_default("Plugins_ae", "test", "#³²¼¬{[µ·…|»¢«¦›©‹³²¼¬")
  options = AE::LaunchUp::Options.new("test")
  assert(options.get_all.length == 0, "It should not read invalid keys from the registry.")
  Sketchup.write_default("Plugins_ae", "test", "[]")
  options = AE::LaunchUp::Options.new("test")
  assert(options.get_all.length == 0, "It should not read invalid keys from the registry.")
  # TODO
  Sketchup.write_default("Plugins_ae", "test", "UI.messagebox('It should not be possible to inject code!'); ")
  # It should only read existing keys from the registry if it is of the same type (class).
  Sketchup.write_default("Plugins_ae", "test", reg)
  options = AE::LaunchUp::Options.new("test", {:key1 => 42, :key2 => "String", :key3 => :Symbol, :key4 => true, :key5 => false})
  assert(options.get(:key1) == 42, "It should only read existing keys from the registry if it is of the same type (class).")
  assert(options.get(:key2) == "String", "It should only read existing keys from the registry if it is of the same type (class).")
  assert(options.get(:key3) == :Symbol, "It should only read existing keys from the registry if it is of the same type (class).")
  assert(options.get(:key4) == true, "It should only read existing keys from the registry if it is of the same type (class).")
  assert(options.get(:key5) == false, "It should only read existing keys from the registry if it is of the same type (class).")
end



def test_set
  # It should set a key/value pair.
  options = AE::LaunchUp::Options.new("test")
  options.set(:key, "value")
  value = options.get(:key)
  assert(value == "value", "It should set a key/value pair.")
  # It should only update an existing key if it is of the same type (class).
  options.set(:key, 42)
  value = options.get(:key)
  assert(value == "value", "It should not allow to change a value to a different type (class).")
  # It should be aliased as []=.
  assert(options.method(:[]=) == options.method(:set), "It should be aliased as []=.")
end



def test_get
  # It should return the value for the given key
  options = AE::LaunchUp::Options.new("test", {:key => "value"})
  value = options.get(:key)
  assert(value == "value", "It should return the value for the given key.")
  # It should be aliased as [].
  assert(options.method(:[]) == options.method(:get), "It should be aliased as [].")
end



def test_type_conversion
  options = AE::LaunchUp::Options.new("test")
  options.set(:key1, "value")
  value = options.get("key1")
  assert(value == "value", "It should accept keys as String or Symbol.")
  options.set("key2", "value")
  value = options.get(:key2)
  assert(value == "value", "It should accept keys as String or Symbol.")
end



def test_get_all
end



def test_update
  Sketchup.write_default("Plugins_ae", "test", "")
  options = AE::LaunchUp::Options.new("test")
  hash = {
    # Symbol as key and JSON types as value
    :key1 => "String", :key2 => :Symbol, :key3 => 42, :key4 => 3.14, :key5 => -2.78, :key6 => nil, :key7 => true, :key8 => false, :key9 => [1,2,3], :key10 => {:key11 => "string2"},
    # String as key and JSON types as value
    "key11" => "String", "key12" => :Symbol, "key13" => 42, "key14" => 3.14, "key15" => -2.78, "key16" => nil, "key17" => true, "key18" => false, "key19" => [1,2,3], "key20" => {"key21" => "string2"},
    # Something else as key
    71 => "String", 1.618 => :Symbol, Object.new => 42, Kernel => 3.14, Proc.new{} => -2.78, Time.now => nil, Regexp.new("") => true, (1..2) => false, nil => [1,2,3], false => {:key11 => "string2"},
    # Something else as value
    :key21 => Object.new, :key22 => Kernel, :key23 => Proc.new{}, :key24 => Time.now, :key25 => Regexp.new(""), :key26 => (1..2),
  }
  # Updates only those that have Symbol/String as key and JSON types as value, and if already contained.
  # valid: [String, Symbol, Fixnum, Float, Array, Hash, TrueClass, FalseClass, NilClass]
  options.update(hash)
  assert( options.get_all.length == 20, "It should update only those that have Symbol/String as key and JSON types as value, and if already contained.")
end



def test_get_json
end



def test_update_json
end



def test_save
  Sketchup.write_default("Plugins_ae", "test", "")
  options = AE::LaunchUp::Options.new("test")
  options.set(:key, "value3")
  options.save
  # It should write a registry key.
  value = Sketchup.read_default("Plugins_ae", "test", "")
  assert(!value.empty?, "Options.save should write a registry key.")
  # It should save the complete options and be able to restore them completely.
  options = AE::LaunchUp::Options.new("test")
  all = options.get_all
  assert(all == {:key => "value3"}, "It should save the complete options and be able to restore them completely.")
end



def test_normalize_keys
  # It should keep only those that have Symbol/String as key and JSON types as value, and if already contained.
end



def test_to_json
  # It should return a string that is valid JSON (to be determined in a browser or any alternative JSON implementation).
end



def test_from_json
  # Clear the registry.
  Sketchup.write_default("Plugins_ae", "test", "")
  json = "{\"key1\":\"string1\",\"key2\":42,\"key3\":3.14,\"key4\":-2.78,\"key5\":null,\"key6\":true,\"key7\":false,\"key8\":[1,2,3],\"key9\":{2:\"string2\"}}"
  hash = {:key1 => "string1", :key2 => 42, :key3 => 3.14, :key4 => -2.78, :key5 => nil, :key6 => true, :key7 => false, :key8 => [1,2,3], :key9 => {2 => "string2"} }
  # It should accept a string argument and update the options if it is valid JSON.
  options = AE::LaunchUp::Options.new("test")
  options.update_json(json)
  assert(options.get_all.length == hash.length, "It should read the complete options from JSON and be able to return them completely.")
  assert(options.get(:key1) == hash[:key1], "It should read string from JSON.")
  assert(options.get(:key2) == hash[:key2], "It should read String from JSON.")
  assert_in_delta(options.get(:key3), hash[:key3], 0.0001, "It should read Float from JSON.")
  assert_in_delta(options.get(:key4), hash[:key4], 0.0001, "It should read negative Float from JSON.")
  assert(options.get(:key5, false).nil?, "It should read NilClass from JSON.")
  assert(options.get(:key6) == true, "It should read TrueClass from JSON.")
  assert(options.get(:key7) == false, "It should read FalseClass from JSON.")
  assert(options.get(:key8) == hash[:key8], "It should read Array from JSON.")
  assert(options.get(:key9) == hash[:key9], "It should read Hash from JSON.")
end



end # class TC_LaunchUp_Options
