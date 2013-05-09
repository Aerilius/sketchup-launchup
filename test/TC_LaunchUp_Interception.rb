require 'sketchup.rb'
require 'test/unit'



class TC_LaunchUp_Interception < Test::Unit::TestCase



# This test only tests that the behavior of the API method is unchanged.



def setup
  require "!ae_LaunchUp/Interception.rb"
end



def teardown
end



def test_interception_menu_add_item
  menu = UI.menu("Plugins")
  item = nil
  assert_nothing_raised("It should not raise an error when giving a String and a Proc argument."){
    item = menu.add_item("menu item 1"){ UI.messagebox("menu item 1") }
  }
  # As of SketchUp 8, this method has always been returning a Fixnum.
  assert(item.is_a?(Fixnum), "It should return a menu id.")

  command = UI::Command.new("menu item 2"){ UI.messagebox("menu item 2") }
  item = nil
  assert_nothing_raised("It should not raise an error when giving a UI::Command argument."){
    item = menu.add_item(command)
  }
  # As of SketchUp 8, this method has always been returning a Fixnum.
  assert(item.is_a?(Fixnum), "It should return a menu id.")
end



def test_interception_menu_add_submenu
  menu = UI.menu("Plugins")
  submenu = nil
  assert_nothing_raised("It should not raise an error when giving a String argument."){
    submenu = menu.add_submenu("submenu 1")
  }
  assert(submenu.is_a?(Sketchup::Menu), "It should return a menu object.")
end



def test_interception_menu_set_validation_proc
  menu = UI.menu("Plugins")
  item = menu.add_item("menu item 3"){ UI.messagebox("menu item 3") }
  item_with_validation_proc = nil
  assert_nothing_raised("It should not raise an error when giving an item id and a Proc argument."){
    item_with_validation_proc = menu.set_validation_proc(item){ rand < 0.5 ? MF_ENABLED : MF_GRAYED }
  }
  assert(item_with_validation_proc, "It should return true.")
end



def test_interception_ui_menu
  menu = nil
  assert_nothing_raised("It should not raise an error when giving a String argument."){
    menu = UI.menu("Plugins")
  }
  assert(menu.is_a?(Sketchup::Menu), "It should return a Sketchup::Menu object")
end



def test_interception_ui_add_context_menu_handler
  handler = nil
  assert_nothing_raised("It should not raise an error when giving a Proc argument."){
    # The proc itself can only be tested manually.
    handler = UI.add_context_menu_handler{ |menu| raise("context menu handler does not receive a Sketchup::Menu argument") unless menu.is_a?(Sketchup::Menu) }
  }
  # As of SketchUp 8, this method has always been returning a Fixnum.
  assert(handler.is_a?(Fixnum), "It should return a Fixnum count of all registered context menu handlers")
end



def test_interception_command_new
  command = nil
  assert_nothing_raised("It should not raise an error when giving a String and a Proc argument."){
    command = UI::Command.new("command 1"){ UI.messagebox("command 1") }
  }
  assert(command.is_a?(UI::Command), "It should return a UI::Command object.")
end



def test_interception_command_set_validation_proc
  command = UI::Command.new("command 2"){ UI.messagebox("command 2") }
  command_with_validation_proc = nil
  assert_nothing_raised("It should not raise an error when giving a Proc argument."){
    command_with_validation_proc = command.set_validation_proc{ rand < 0.5 ? MF_ENABLED : MF_GRAYED }
  }
  assert(command_with_validation_proc.is_a?(UI::Command), "It should return a UI::Command object.")
end



end # class TC_LaunchUp_Interception
