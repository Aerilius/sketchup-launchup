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

Version:      1.0.6

Date:         08.04.2013

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
# Since the API does not expose the procs in UI::Command and the
# menu name and proc in Sketchup::Menu, we try to get those via aliasing and
# intercepting the API methods that create them.
require(File.join(PATH_ROOT, 'Interception.rb'))
# Add SketchUp's native (non-Ruby) commands to ObjectSpace so we can access them by the same means as plugins:
# If it contains errors, we can skip this file.
require(File.join(PATH_ROOT, 'commands', 'Commands.rb')) rescue puts("AE::LaunchUp couldn't load #{File.join(PATH_ROOT, 'commands', 'Commands.rb')}.")
# Index that performs searches.
require(File.join(PATH_ROOT, 'Index.rb'))
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
WIN = ( RUBY_PLATFORM =~ /mswin/i ) unless defined?(self::WIN)



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
    @launchdlg = AE::LaunchUp::Dialog.new(TRANSLATE["LaunchUp"], false, false, 800, 200, @options[:width], 60, true)
    @launchdlg.min_width = 150
    @launchdlg.max_width = 500
    @launchdlg.min_height = 40
    window_width = (@options[:width].is_a?(Numeric)) ? @options[:width] : 250 # outer width
    window_height = 40 # outer height
    @launchdlg.set_size(window_width, window_height)
    html_path = File.join(PATH_ROOT, "html", "LaunchUp.html")
    @launchdlg.set_file(html_path)

    @launchdlg.on_show {|dlg|
      TRANSLATE.webdialog(dlg)
      dlg.execute_script("AE.LaunchUp.initialize(#{@options.get_json})")
    }

    # Update the @options object in Ruby.
    @launchdlg.on("updateOptions") { |dlg, hash|
      @options.update(hash)
      nil
    }

    # Load the index.
    @launchdlg.on("load_index") { |dlg, param|
      dlg.execute_script("AE.LaunchUp.Index.load(#{Index.instance.to_json})") if @options[:local_index]
    }

    # Send entries from the Index to the WebDialog.
    @launchdlg.on("get_entries") { |dlg, ids|
      entries = ids.map{|id| Index.instance.get_by_id(id)}
    }

    # Search the index.
    @launchdlg.on("look_up") { |dlg, search_string|
      # We better get the string directly from the input instead of encoding/unencoding. This preserves Unicode characters.
      search_string = dlg.get_element_value("combo_input")
      length = (@options[:max_length].is_a?(Fixnum)) ? @options[:max_length] : nil
      # In case of failure, nil gives the method's default value.
      results = Index.instance.look_up(search_string, length)
    }

    # Execute an action.
    @launchdlg.on("execute") { |dlg, id|
      success = Index.instance.execute(id)
      @options[:tracking][id] = Index.instance.get_by_id(id)[:track] if success
      dlg.close if @options[:pinned] == false
      success
    }

    # Close
    @launchdlg.set_on_close {
      @options.save
      puts("Dialog closed and options saved") if @options[:debug]
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
    @optionsdlg = AE::LaunchUp::Dialog.new(TRANSLATE["LaunchUp Options"], false, false, 600, 200, 500, 300, true)
    @optionsdlg.min_width = 300
    @optionsdlg.max_width = 600
    @optionsdlg.min_height = 300
    window_width = 500 # outer width
    window_height = 300 # outer height
    @optionsdlg.set_size(window_width, window_height)
    html_path = File.join(PATH_ROOT, "html", "LaunchUpOptions.html")
    @optionsdlg.set_file(html_path)

    # Callbacks
    # initialize: Pass the default options to the form.
    @optionsdlg.on_show {|dlg|
      dlg.execute_script("document.getElementsByTagName('body')[0].style.background='#{dlg.get_default_dialog_color}'")
      TRANSLATE.webdialog(dlg)
      dlg.execute_script("AE.LaunchUpOptions.initialize(#{@options.get_json})")
    }

    # Update the options.
    @optionsdlg.on("updateOptions") { |dlg, hash|
      @options.update(hash)
      @options.save
      # Try to update options in LaunchUp dialog.
      if @launchdlg && @launchdlg.visible?
        json = @options.get_json
        @launchdlg.execute_script("
          var opt = #{json};
          for (var i in opt) { AE.LaunchUp.Options[i] = opt[i] };
          AE.LaunchUp.updateColors();
          AE.LaunchUp.ComboBox.updateStyle();
          AE.LaunchUp.History.updateStyle();
        ")
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



class << self
  private
  def create_index
    index = Index.instance
    index.load_tracking(@options[:tracking])
    return index
  end
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
