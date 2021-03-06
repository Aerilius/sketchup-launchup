=begin
Copyright 2011-2013, Andreas Eisenbarth
All Rights Reserved

Permission to use, copy, modify, and distribute this software for
any purpose and without fee is hereby granted, provided that the above
copyright notice appear in all copies.

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

Name:         LaunchUp.rb

Author:       Andreas Eisenbarth

Usage:        Menu 'Plugins' → 'LaunchUp – Tool Launcher'
              or create a shortcut, for example ctrl+space

Description:  This Plugin adds a quick launcher to search and execute commands.
              • You can search for native SketchUp functions as well as plugins
                and select them by mouse or keyboard.
              • Click the history/clock button to toggle a list of recently used
                commands that you don't need to search anymore (this can be used
                as a dynamic toolbar).
              • Search for "LaunchUp – Options" to change settings.

Recommended:  SketchUp 8 M2 or higher (it works in a limited way in lower versions)

Version:      1.0.16

Date:         27.05.2013

Note:
  This plugin has only been possible by modifying (intercepting) SketchUp API
  methods, since the API lacks some methods (UI::Command.proc). These should not
  have bad side-effects, however if you notice problems, remove this plugin and
  notify me.

Issues:
  On OSX, an unfocussed webdialog absorbs the first click to focus itself. You might
  want to get used to double-clicking.
  The dialog can flicker slightly on OSX when resizing causes SketchUp/OSX to move
  the dialog up, and then the plugin tries to preserve the dialog's position.

Remarks on file sorting:
  To ensure that this plugin has access to all other plugins, it needs to be loaded
  first. It should be loaded at first (or at least early) when we set the first
  letter of the loader file so it comes first in Ruby's load order.

  Windows:
  Console: !$&()+,-.09@AZ^_
 Explorer: !$&(),.-@^_+09AZ
→    Ruby: !$&()+,-.09@AZ^_

      OSX:
 Terminal: !$&()+,-09@AZ^_
→    Ruby: !$&()+,-09@^_AZ

Public methods:
  You can use these methods to use LaunchUp in Ruby code:

AE::LaunchUp.look_up(search_string=[String], length=[Fixnum])
  Queries the index for seach terms and returns an Array of hashes as results.
  You can specify the amount of results. The resulting contains keys like:
  :name, :description, :icon, :category, :keywords, :proc, :validation_proc, :id

AE::LaunchUp.execute(identifier)
  Execute a command from the index, specified by the :id obtained from #look_up.
  It returns a boolean indicating success or failure (command not found or failed
  to execute).

=end
require 'sketchup.rb'



module AE



module LaunchUp



# This plugin's folder.
PATH_ROOT = File.dirname(__FILE__) unless defined?(self::PATH_ROOT)
# Translation library.
require(File.join(PATH_ROOT, 'Translate.rb'))
# Load translation strings and add plugin to UI.
TRANSLATE = Translate.new("LaunchUp", File.join(PATH_ROOT, "lang")) unless defined?(self::TRANSLATE)
# WebDialog Helper.
require(File.join(PATH_ROOT, 'Dialog.rb'))
# Index that performs searches.
require(File.join(PATH_ROOT, 'Index.rb'))
# Add SketchUp's native (non-Ruby) commands to ObjectSpace so we can access them by the same means as plugins:
# If it contains errors, we can skip this file.
begin
  require(File.join(PATH_ROOT, 'commands', 'Commands.rb'))
rescue LoadError
  $stderr.write("AE::LaunchUp couldn't load #{File.join(PATH_ROOT, 'commands', 'Commands.rb')}." << $/)
end
# Options.
require(File.join(PATH_ROOT, 'Options.rb'))
@options ||= Options.new("LaunchUp", {
  :max_length => 10, # The maximum number of search results. (currently only in the Ruby Index)
  :pinned => true,
  :width => 270,
  :color => 'ButtonFace', # The background color of the LaunchUp dialog,
    # one member of [ButtonFace, Menu, Window, ActiveCaption, InactiveCaption, custom]
  :color_custom => '#dddddd', # A CSS color expression if :color == 'custom'
  :color_custom_text => '#222222',
  :style_suggestions => 'wide', # The style and layout of the list items (CSS class).
  :style_history => 'slim', # The style and layout of the list items (CSS class).
  :show_history => false, # Whether to show the history (list of recent actions).
  :history_max_length => 10, # The maximum number of items in the history.
  :history_entries => [], # The list of recently used commands (their IDs).
  :debug => false,
  :tracking => {}, # This hash keeps track how often a command was executed.
})
# Reference to the main dialog.
@launchdlg ||= nil



# Platform detection.
OSX = ( Object::RUBY_PLATFORM =~ /darwin/i ) unless defined?(self::OSX)
WIN = ( Object::RUBY_PLATFORM =~ /mswin/i || Object::RUBY_PLATFORM =~ /mingw/i ) unless defined?(self::WIN)



public



# This enables log messages and debugging tweaks.
# @params [Boolean,nil] bool whether to enable debugging
def self.debug=(bool=nil)
  return unless @options && (bool==true || bool==false)
  @launchdlg.execute_script("AE.debug = #{bool}; AE.LaunchUp.Options = #{bool}") if @launchdlg && @launchdlg.visible?
  @options[:debug] = bool
end



# This returns whether debugging is enabled.
# @returns [Boolean] debug
def self.debug
  return @options[:debug]
end



# This displays the main dialog with search field.
def self.show_dialog
  # If the dialog exists, bring it to the front.
  if @launchdlg && @launchdlg.visible?
    @launchdlg.bring_to_front
  else
    @launchdlg = AE::LaunchUp::Dialog.new(TRANSLATE["LaunchUp"], false, "AE_LaunchUp", @options[:width], 60, 800, 200, true)
    @launchdlg.min_width = 150 if @launchdlg.respond_to?(:min_width)
    @launchdlg.min_height = 40 if @launchdlg.respond_to?(:min_height)
    window_width = (@options[:width].is_a?(Numeric)) ? @options[:width] : 270 # outer width
    window_height = 40 # outer height
    @launchdlg.set_size(window_width, window_height)
    html_path = File.join(PATH_ROOT, "html", "LaunchUp.html")
    @launchdlg.set_file(html_path)

    @launchdlg.on_show { |dlg|
      TRANSLATE.webdialog(dlg)
      dlg.call_function("AE.LaunchUp.initialize", @options.get_all) # TODO ##############################################
    }

    # Update the @options object in Ruby.
    @launchdlg.on("update_options") { |dlg, hash|
      @options.update(hash)
    }

    # Load the index.
    @launchdlg.on("load_index") { |dlg, param|
      dlg.call_function("AE.LaunchUp.Index.load", Index.instance.get_all) if @options[:local_index]
    }

    # Send entries from the Index to the WebDialog.
    @launchdlg.on("get_entries") { |dlg, ids|
      dlg.return ids.map{|id| Index.instance.get_by_id(id)}
    }

    # Search the index.
    @launchdlg.on("look_up") { |dlg, search_string|
      length = (@options[:max_length].is_a?(Fixnum)) ? @options[:max_length] : nil
      # In case of failure, nil gives the method's default value.
      dlg.return Index.instance.look_up(search_string, length)
    }

    # Execute an action.
    @launchdlg.on("execute") { |dlg, id|
      success = Index.instance.execute(id)
      @options[:tracking][id] = Index.instance.get_by_id(id)[:track] if success
      dlg.close if @options[:pinned] == false
      dlg.return success
    }

    # Close
    @launchdlg.on_close{
      @options[:width] = @launchdlg.width
      @options.save
      puts("Dialog closed and options saved") if @options[:debug]
      @launchdlg = nil if @options[:debug]
    }

    # Show the webdialog.
    if OSX
      @launchdlg.show_modal
    else
      @launchdlg.show
    end

  end
  return @launchdlg
end



# This method displays the options dialog.
def self.show_options
  # If the dialog exists, bring it to the front.
  if @optionsdlg && @optionsdlg.visible?
    @optionsdlg.bring_to_front
  else
    # Create the WebDialog.
    @optionsdlg = AE::LaunchUp::Dialog.new(TRANSLATE["LaunchUp – Options"], false, "AE_LaunchUp_Options", 400, 300, 600, 200, true)
    @optionsdlg.min_width = 300 if @launchdlg.respond_to?(:min_width)
    @optionsdlg.min_height = 300 if @launchdlg.respond_to?(:min_height)
    html_path = File.join(PATH_ROOT, "html", "LaunchUpOptions.html")
    @optionsdlg.set_file(html_path)

    # Callbacks
    # initialize: Pass the default options to the form.
    @optionsdlg.on_show {|dlg|
      TRANSLATE.webdialog(dlg)
      dlg.call_function("AE.LaunchUpOptions.initialize", @options.get_all) ###############################
      dlg.set_position_center
    }

    # Update the options.
    @optionsdlg.on("update_options") { |dlg, hash|
      @options.update(hash)
      @options.save
      # Try to update options in LaunchUp dialog.
      if @launchdlg && @launchdlg.visible?
        @launchdlg.call_function("AE.LaunchUp.update", @options.get_all)
      end
    }

    # Show the webdialog.
    if OSX
      @optionsdlg.show_modal
    else
      @optionsdlg.show
    end
  end

  return @optionsdlg
end



# API



# Public method to query the index with a search.
# @param [String] search_string
# @param [Fixnum] length the maximum number of results.
# @returns [Array] an array of sorted results of the form:
#   {:name => ..., :description => ..., :id => ..., :proc => ..., :validation_proc => ...}
def self.look_up(search_string, length=@options[:max_length])
  raise(ArgumentError, "First argument 'search_string' must be a String.") unless search_string.is_a?(String)
  raise(ArgumentError, "Second argument 'length' must be a Fixnum.") unless length.is_a?(Fixnum)
  Index.instance.look_up(search_string, length)
end



# Execute a command from the index.
# @param [Fixnum] identifier the ID of the command to be executed.
# @returns [Boolean] whether the command was executed (otherwise not found)
def self.execute(identifier)
  raise(ArgumentError, "Argument 'identifier' must be a Fixnum.") unless identifier.is_a?(Fixnum)
  return Index.instance.execute(identifier)
end



# Resets the options to the plugin's original state.
def self.reset
  @options.reset
end



# Dumps the index to a file as JSON string, for debugging.
# This can be used in a web browser with:
#   AE.LaunchUp.initialize();
#   AE.LaunchUp.Options.local_index = true;
#   AE.LaunchUp.Index.load(this_array);
# @param [String] file where to save the index.
def self.save_index(file=nil, json=false)
  file = UI.savepanel if file.nil? || !File.exists?(file)
  return if file.nil?
  File.open(file, "w"){|f|
    if json == true
      f.puts(Index.instance.to_json)
    else
      # We only want to include classes whose inspect value contains a valid Ruby object.
      classes = [String, Numeric, Array, Hash, TrueClass, FalseClass, NilClass]
      array = Index.instance.instance_variable_get(:@data).map{|entry| new = {}
        entry.each{|k,v| new[k] = v if classes.include?(k.class) && classes.include?(v.class)}
        new
      }
      f.puts(array.inspect)
    end
  }
end



unless file_loaded?(File.basename(__FILE__))



  # Add this plugin to the UI
  cmd_launchup = UI::Command.new(TRANSLATE["LaunchUp – Quick Launcher"]){ AE::LaunchUp.show_dialog }
  cmd_launchup.tooltip = TRANSLATE["A searchable quick launcher for SketchUp tools."]
  cmd_launchup.small_icon = File.join(PATH_ROOT, "images", "icon_launchup_16.png")
  cmd_launchup.large_icon = File.join(PATH_ROOT, "images", "icon_launchup_24.png")
  cmd_launchup.set_validation_proc {
    (@launchdlg && @launchdlg.visible?) ? MF_CHECKED : MF_UNCHECKED
  }
  UI.menu("Plugins").add_item(cmd_launchup)

  cmd_options = UI::Command.new(TRANSLATE["LaunchUp – Options"]){ AE::LaunchUp.show_options }
  cmd_options.tooltip = TRANSLATE["Options to customize the look and behavior of LaunchUp."]
  cmd_options.small_icon = File.join(PATH_ROOT, "images", "icon_options_16.png")
  cmd_options.large_icon = File.join(PATH_ROOT, "images", "icon_options_24.png")
  def cmd_options.keywords; return ["options", "settings", "preferences"]; end
  # UI.menu("Plugins").add_item(cmd_options) # We don't clutter the menu more, this is already accessible through LaunchUp.



  file_loaded(File.basename(__FILE__))
end # end unless



end # module LaunchUp



end # module AE
