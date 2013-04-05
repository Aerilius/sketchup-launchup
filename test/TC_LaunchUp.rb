require 'sketchup.rb'
require 'test/unit'



class TC_LaunchUp < Test::Unit::TestCase



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



# This test checks the option :selection_mode to modify only materials on the selected faces.
def test_debug
  value = (AE::LaunchUp.debug = true)
  result = AE::LaunchUp.instance_variable_get(:@options)[:debug] # TODO: check instance/class variable
  assert(value == result && value == true, "It should enable debugging and return the new value (true).")
  value = (AE::LaunchUp.debug = false)
  result = AE::LaunchUp.instance_variable_get(:@options)[:debug] # TODO: check instance/class variable
  assert(value == result && value == false, "It should disable debugging and return the new value (false).")
end



def test_show_dialog
  # The index should initialize if it isn't already.
  index = AE::LaunchUp.instance_variable_get(:@index)
  index_initialized0 = index.is_a?(AE::LaunchUp::Index)
  dlg = AE::LaunchUp.show_dialog
  index_initialized1 = index.is_a?(AE::LaunchUp::Index)
  assert(index_initialized0 == index_initialized1, "Opening LaunchUp initializes index.") unless index_initialized0
  # The dialog should open in front of SketchUp (Windows: show, OSX: show_modal) and focus the input field (JavaScript AE.LaunchUp.initialize).
  # The dialog should be translated.
  # The dialog should receive the options and initialize (test javascript separately).
  # The dialog should send back the window size to achieve the window_border_width
  # and window_titlebar_height and adjust its size, but we don't know the size.
  # The callback look_up should trigger if a onkeyup event fires on the search input.
  # More JavaScript tests etc.
  # The dialog should close and save the options when the window close button is
  # clicked as well as when pinned==false after executing a command.
end



def test_look_up
  index = AE::LaunchUp::Index.instance
  # It should accept string and optionally Fixnum as parameters.
  assert_nothing_raised("It should accept string as first argument.") { AE::LaunchUp.look_up("something") }
  assert_raise(ArgumentError, "It should accept only string as first argument.") { AE::LaunchUp.look_up(42) }
  assert_raise(ArgumentError, "It should accept only string as first argument.") { AE::LaunchUp.look_up(3.14) }
  assert_raise(ArgumentError, "It should accept only string as first argument.") { AE::LaunchUp.look_up(Object.new) }
  assert_nothing_raised("It should accept string as first argument.") { AE::LaunchUp.look_up("something", 42) }
  assert_raise(ArgumentError, "It should accept only string as first argument.") { AE::LaunchUp.look_up("something", "something") }
  assert_raise(ArgumentError, "It should accept only string as first argument.") { AE::LaunchUp.look_up("something", 3.14) }
  assert_raise(ArgumentError, "It should accept only string as first argument.") { AE::LaunchUp.look_up("something", Object.new) }
  # It should return an array of hashes (search results).
  result = AE::LaunchUp.look_up("not existing")
  assert(result.is_a?(Array), "It should return an array.")
  index.add(nil, { :name => "exists", :proc => Proc.new{} })
  result = AE::LaunchUp.look_up("exists")
  assert(!result.find{|e| !e.is_a?(Hash)}, "It should return an array of hashes.")
  # Make sure we get many results (by editing the name later to be identical).
  index.clear
  20.times{|i| index.add(nil, { :name => "#{i}", :proc => Proc.new{} }) }
  10.times{|i| index.get_all.find{|e| e[:name] == "#{i}"}[:name]="exists" }
  # It should default to @options[:max_length] results.
  max_length = AE::LaunchUp.instance_variable_get(:@options)[:max_length]
  assert(AE::LaunchUp.look_up("exists").length <= max_length, "It should default to @options[:max_length] results.")
  # It should not return more results than second parameter or @options[:max_length].
  assert(AE::LaunchUp.look_up("exists", 20).length <= 20, "It should not return more results than requested.")
  assert(AE::LaunchUp.look_up("exists", 10).length <= 10, "It should not return more results than requested.")
  assert(AE::LaunchUp.look_up("exists", 1).length <= 1, "It should not return more results than requested.")
  assert(AE::LaunchUp.look_up("exists", 0).length <= 0, "It should not return more results than requested.")
  # It should return the same results as index.look_up.
end



def test_execute
  # Should accept an object (Fixnum) as identifier.
  # Should return false if index not initialized. TODO: or it should initialize the index.
  # short: Should return result of @index.execute
  ## Should return false if the requested command (by identifier) does not exist.
  ## Should return false if the requested command failed to execute.
  ## Should return true if the requested command executed successfully.
end



def test_save_index
  # Should accept filepath or ask for filepath with savepanel.
  # Should write index as JSON to text file.
end



end # class TC_LaunchUp
