require 'sketchup.rb'
require 'test/unit'



class TC_LaunchUp_Index < Test::Unit::TestCase



def setup
  begin
    index = AE::LaunchUp::Index.instance
    def index.clear; @data.clear; end
    def index.get_all; return @data; end
  rescue Exception
  end
end



def teardown
end



def test_index_instance
  index = AE::LaunchUp::Index.instance
  # It should create only one instance and return always the same instance.
  index2 = AE::LaunchUp::Index.instance
  assert_equal(index, index2, "It should create only one instance and return always the same instance.")
  # It should not be possible to create a new instance.
  assert(!AE::LaunchUp::Index.respond_to?(:new), "It should not be possible to create a new instance.")
  # It should fill @data with all commands whose Proc is available (ie. commands that
  # have been aliased in AE::Interception::Command.commands + those that (in future)
  # respond to :proc).
end



def test_index_add
  index = AE::LaunchUp::Index.instance
  index.clear
  # It should accept UI::Command and optionally hash with additional/overriding data.
  assert_nothing_raised("It should accept UI::Command as argument.") { index.add(UI::Command.new("something"){}) }
  assert_nothing_raised("It should accept Hash as argument.") { index.add({}) }
  assert_nothing_raised("It should accept a UI::Command and a Hash as argument.") { index.add(UI::Command.new("something"){}, {}) }
  assert_nothing_raised("It should accept a Hash and a UI::Command as argument.") { index.add({}, UI::Command.new("something"){}) }

  # It should not add an entry if it lacks substantial data, namely
  # for a UI::Command: AE::Interception::Command.procs must include a proc for this command
  # for a Hash: it must contain a key :proc with a value that is a Proc, and :name

  # It should not take an :id passed to it.
  index.add(nil, {:name => "ID Test", :proc => Proc.new{}, :id => 123456789 })
  id = index.get_all.find{|e| e[:name] == "ID Test"}[:id]
  assert(id != 123456789, "It should not take an :id passed to it.")

  # It should add an :id identifier produced from #hash_code (assuming the private instance variable is called @data).

  # Should add a hash into @data array under the condition that the command or hash
  # has a :proc and an :id that is not yet in array.
  # Should return this hash.
end



def test_index_update
  # Should accept a hash.
  # Should find existing hash in @data with same :command or same :id, and if found,
  # merge new hash (overriding properties of old hash) and return true, otherwise false.
end



def test_index_look_up
  index = AE::LaunchUp::Index.instance
  index.clear
  # It should accept string and optionally fixnum as parameters.
  assert_nothing_raised("It should accept string as first argument.") { index.look_up("something") }
  assert_raise(ArgumentError, "It should accept only string as first argument.") { index.look_up(42) }
  assert_raise(ArgumentError, "It should accept only string as first argument.") { index.look_up(3.14) }
  assert_raise(ArgumentError, "It should accept only string as first argument.") { index.look_up(Object.new) }
  assert_nothing_raised("It should accept string as first argument.") { index.look_up("something", 42) }
  assert_raise(ArgumentError, "It should accept only string as first argument.") { index.look_up("something", "something") }
  assert_raise(ArgumentError, "It should accept only string as first argument.") { index.look_up("something", 3.14) }
  assert_raise(ArgumentError, "It should accept only string as first argument.") { index.look_up("something", Object.new) }
  # Should return array of hashes (search results).
  result = index.look_up("not existing")
  assert(result.is_a?(Array), "It should return an array.")
  index.add(nil, { :name => "exists", :proc => Proc.new{} })
  result = index.look_up("exists")
  assert(!result.find{|e| !e.is_a?(Hash)}, "It should return an array of hashes.")
  # It should not return more results than second parameter.
  # Make sure we get many results (by editing the name later to be identical).
  index.clear
  20.times{|i| index.add(nil, { :name => "#{i}", :proc => Proc.new{} }) }
  10.times{|i| index.get_all.find{|e| e[:name] == "#{i}"}[:name]="exists" }
  assert(index.look_up("exists", 20).length == 10, "It should return as many results as found.")
  assert(index.look_up("exists", 10).length == 10, "It should return as many results as found.")
  assert(index.look_up("exists", 1).length <= 1, "It should not return more results than requested.")
  assert(index.look_up("exists", 0).length <= 0, "It should not return more results than requested.")
end



def test_index_get_by_id
  index = AE::LaunchUp::Index.instance
  index.clear
  # It should accept an object (Fixnum) as identifier
  assert_nothing_raised("It should accept Fixnum as argument.") { index.get_by_id(42) }
  assert_raise(ArgumentError, "It should accept only Fixnum as argument.") { index.get_by_id("something") }
  assert_raise(ArgumentError, "It should accept only Fixnum as argument.") { index.get_by_id(3.14) }
  assert_raise(ArgumentError, "It should accept only Fixnum as argument.") { index.get_by_id(Object.new) }
  # It should return nil if no hash is found for the given id.
  assert(index.get_by_id(42).nil?, "It should return nil if no hash is found for the given id.")
  # It should return the hash if it has the identifier as :id
  hash = { :name => "exists", :proc => Proc.new{} }
  index.add(nil, hash)
  id = index.get_all.find{|e| e[:name] == "exists" }[:id]
  assert(index.get_by_id(id) == hash, "It should return the hash if it has the identifier as :id.")
end



def test_index_execute
  index = AE::LaunchUp::Index.instance
  index.clear
  index.add(nil, { :name => "Success1", :proc => Proc.new{} })
  index.add(nil, { :name => "Success2", :proc => Proc.new{true} })
  index.add(nil, { :name => "Failure1", :proc => Proc.new{error} })
  index.add(nil, { :name => "Failure2", :proc => Proc.new{false} })
  # It should accept an object (Fixnum) as identifier.
  arity = index.method(:execute).arity
  assert(arity != 0 && (arity > 0 || arity < -1), "It should require one argument.")
  assert_nothing_raised("It should accept a Fixnum.") { index.execute(42) }
  # It should return false if the requested command is not found.
  assert( index.execute(10**9) == false, "It should return false if the requested command is not found.")
  # It should return false if the requested command failed to execute.
  id = index.get_all.find{|e| e[:name] == "Failure1"}[:id]
  assert( index.execute(id) == false, "It should return false if the requested command failed to execute.")
  id = index.get_all.find{|e| e[:name] == "Failure2"}[:id]
  assert( index.execute(id) == false, "It should return false if the requested command failed to execute.")
  # It should return true if the requested command executed successfully.
  id = index.get_all.find{|e| e[:name] == "Success1"}[:id]
  assert( index.execute(id) == true, "It should return true if the requested command executed successfully.")
  id = index.get_all.find{|e| e[:name] == "Success2"}[:id]
  assert( index.execute(id) == true, "It should return true if the requested command executed successfully.")
end



def test_index_to_json
  # Should accept any object as parameter (preferably compatible with JSON specification), or take @data.
  # Should return a String.
  # The returned String should comply with JSON specification.
end



def test_index_hash_code
  index = AE::LaunchUp::Index.instance
  # It should accept any object (preferably String because of better reproducibility).
  some_objects = ["a string", 42, 3.14, Object.new, Proc.new{}, Kernel, AE::LaunchUp::Index, AE::LaunchUp::Index.instance, ]
  assert_nothing_raised("It should accept any object.") {
    some_objects.each{|o| index.__send__(:hash_code, o) }
  }
  # It should return Fixnum that is the same for the same input data (reproducible).
  assert(index.__send__(:hash_code, "string").is_a?(Fixnum), "It should return Fixnum.")
  assert_equal(index.__send__(:hash_code, "string"), index.__send__(:hash_code, "string"), "It should return the same for the same input data.")
  # It should return different Fixnums for different input data.
  assert(index.__send__(:hash_code, "string") != index.__send__(:hash_code, "string1"), "It should return different Fixnums for different input data.")
  assert(index.__send__(:hash_code, "string") != index.__send__(:hash_code, "String"), "It should return different Fixnums for different input data.")
  assert(index.__send__(:hash_code, "string") != index.__send__(:hash_code, "strin"), "It should return different Fixnums for different input data.")
end



def test_index_find
  # Should accept one String parameter.
  # Should search it through various data in @data and return an array of matching hashes.
  # Should add :score to hashes.
end



def test_index_rank
  # Should accept array of hashes.
  # Should return sorted array by hash[:score].
end



def test_index_slice
  # Should accept array and optional Fixnum defaulted to 10.
  # Should return array no longer than second parameter or 10.
end



end # class TC_LaunchUp_Index
