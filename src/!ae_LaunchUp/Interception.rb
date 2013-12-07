module AE


module Interception



# This module collects data from SketchUp's menu methods to provide access to
# what the API currently lacks:
# :parent and :children of a menu item, :menu_text, :command (or :proc), :validation_proc (or :validate)
#
# For simplicity, it only includes the collected raw data in flat hashes.
# You can look up information and construct your own data structures. Each hash
# uses a Sketchup::Menu or a menu item's id [Fixnum] as key. If you don't know
# the key, do a reverse lookup using Hash.index (Ruby 1.8.6) or Hash.key (Ruby 1.9).
module Menu
  @listeners ||= {}  # An array of Procs
  @menu_items ||= [] # menu_item_id
  @menu_text ||= {}  # menu/menu_item_id => menu_text # equals UI::command.menu_text
  @children ||= {}   # menu              => [menu, menu_item_id, ...]
  @validation_proc ||= {} # menu_item_id => proc
  @proc ||= {}       # menu/menu_item_id => proc
  @command ||= {}    # menu_item_id      => ui_command
  @parent ||= {}     # menu/menu_item_id => menu

  class << self
    attr_reader :menu_items, :menu_text, :children, :validation_proc, :proc, :command, :parent
  end

  # You can pass a Proc through this method to be notified when an intercepted method is called.
  # The Proc will take the caller, arguments and evt. code block as parameters.
  # Note: Code blocks will be passed as normal arguments.
  # @public
  def self.add_listener(method_name=:add_item, &block)
    return unless block_given?
    @listeners[method_name] ||= []
    @listeners[method_name] << block
    nil
  end

  # @private
  def self.listen(*args, &block)
    method_name = args.shift.to_sym
    return unless @listeners.include?(method_name) && @listeners[method_name].is_a?(Array)
    @listeners[method_name].each{|proc| proc.call(*(args << block)) rescue nil }
  rescue Exception => e
    $stderr.write("Error in ae_LaunchUp/Interception.rb for AE::Interception::Menu.listen" << $/)
    $stderr.write(e.message << $/)
    $stderr.write(e.backtrace.join($/) << $/)
  end

  # Get the full menu path of a menu item.
  # @param [Fixnum, UI::Command] item an identifier of the menu item, or the command attached to it.
  # @returns [Array<String>] array of menu texts
  def self.get_menu_path(item)
    if item.is_a?(UI::Command)
      menu_item = self.command.respond_to?(:key) ? self.command.key(item) : self.command.index(item) # Reverse lookup.
    elsif @menu_items.include?(item)
      menu_item = item
    end
    path = []
    # Search for parent menus.
    while menu_item
      menu_text = self.menu_text[menu_item] || ""
      path.unshift(menu_text) unless menu_text.nil?
      menu_item = self.parent[menu_item]
    end
    return path
  end

end # module Menu



# This module collects data from SketchUp's command methods to provide access to
# what the API currently lacks:
# :proc, :validation_proc (or :validate)
#
module Command
  @listeners ||= {}  # An array of Procs
  @commands ||= [] # UI::Command
  @text ||= {}  # command => text
  @proc ||= {}  # command => proc
  @validation_proc ||= {} # command => proc

  class << self
    attr_reader :commands, :text, :proc, :validation_proc
  end

  # You can pass a Proc through this method to be notified when an intercepted method is called.
  # The Proc will take the caller, arguments and evt. code block as parameters.
  # Note: Code blocks will be passed as normal arguments.
  # @public
  def self.add_listener(method_name=:new, &block)
    return unless block_given?
    @listeners[method_name] ||= []
    @listeners[method_name] << block
    nil
  end

  # @private
  def self.listen(*args, &block)
    method_name = args.shift.to_sym
    return unless @listeners.include?(method_name) && @listeners[method_name].is_a?(Array)
    @listeners[method_name].each{|proc| proc.call(*(args << block)) rescue nil }
  rescue Exception => e
    $stderr.write("Error in ae_LaunchUp/Interception.rb for AE::Interception::Command.listen" << $/)
    $stderr.write(e.message << $/)
    $stderr.write(e.backtrace.join($/) << $/)
  end

end # module Command



end # module Interception



end # module AE



# Since the API does not expose the procs in UI::Command and the
# menu name and proc in Sketchup::Menu, we try to get those via aliasing and
# intercepting the API methods that create them.
unless file_loaded?(__FILE__)



class Sketchup::Menu
  # Important: This should be done only once, otherwise we get a circle reference!
  # Using twice the same alias would create a method that references its alias
  # and thus itself. By using "method_defined?" we can avoid that a reloaded or
  # copied version of this script creates an alias that is referenced in the
  # aliased method itself.
  # Additionally a unique alias with an md5 hash of my name space should avoid
  # clashes if someone else does also alias, however nobody should use my alias
  # without checking "method_defined?".

  unless method_defined?(:add_item_orig_2d3b68a6)
    alias_method :add_item_orig_2d3b68a6, :add_item
    private :add_item_orig_2d3b68a6

    def add_item(*args, &block)
      id = add_item_orig_2d3b68a6(*args)
      # On wrong arguments, SketchUp returns nil.
      return id if id.nil?
      # Register data.
      AE::Interception::Menu.menu_items << id
      AE::Interception::Menu.menu_text[id] = args[0].is_a?(UI::Command) ? AE::Interception::Command.text[args[0]] : args[0] # menu_text is not supported by SU < 8M1
      AE::Interception::Menu.command[id] = args[0] if args[0].is_a?(UI::Command)
      AE::Interception::Menu.proc[id] = block if block.is_a?(Proc)
      AE::Interception::Menu.children[self] ||= []
      AE::Interception::Menu.children[self] << id
      AE::Interception::Menu.parent[id] = self
      # Trigger event.
      AE::Interception::Menu.listen(:add_item, self, *args, &block)
    rescue Exception => e
      $stderr.write("Error in ae_LaunchUp/Interception.rb for Sketchup::Menu.add_item" << $/)
      $stderr.write(e.message << $/)
      $stderr.write(e.backtrace.join($/) << $/)
    ensure
      return id
    end
  end # unless

  unless method_defined?(:add_submenu_orig_2d3b68a6)
    alias_method :add_submenu_orig_2d3b68a6, :add_submenu
    private :add_submenu_orig_2d3b68a6

    def add_submenu(*args)
      submenu = add_submenu_orig_2d3b68a6(*args)
      # On wrong arguments, SketchUp returns nil.
      return submenu if submenu.nil?
      # Register data.
      AE::Interception::Menu.menu_text[submenu] = args[0]
      AE::Interception::Menu.children[self] ||= []
      AE::Interception::Menu.children[self] << submenu
      AE::Interception::Menu.parent[submenu] = self
      # Trigger event.
      AE::Interception::Menu.listen(:add_submenu, self, *args)
    rescue Exception => e
      $stderr.write("Error in ae_LaunchUp/Interception.rb for Sketchup::Menu.add_submenu" << $/)
      $stderr.write(e.message << $/)
      $stderr.write(e.backtrace.join($/) << $/)
    ensure
      return submenu
    end
  end # unless

  unless method_defined?(:set_validation_proc_orig_2d3b68a6)
    alias_method :set_validation_proc_orig_2d3b68a6, :set_validation_proc
    private :set_validation_proc_orig_2d3b68a6

    def set_validation_proc(*args, &block)
      success = set_validation_proc_orig_2d3b68a6(*args, &block)
      if success
        # Register data.
        AE::Interception::Menu.validation_proc[args[0]] = block
        # Trigger event.
        AE::Interception::Menu.listen(:set_validation_proc, self, *args, &block)
      end
    rescue Exception => e
      $stderr.write("Error in ae_LaunchUp/Interception.rb for Sketchup::Menu.set_validation_proc" << $/)
      $stderr.write(e.message << $/)
      $stderr.write(e.backtrace.join($/) << $/)
    ensure
      return success || false
    end
  end # unless

end # class Sketchup::Menu



module UI

  class << self
    unless method_defined?(:menu_orig_2d3b68a6)
      alias_method :menu_orig_2d3b68a6, :menu
      private :menu_orig_2d3b68a6

      def menu(*args)
        menu = menu_orig_2d3b68a6(*args)
        return menu if menu.nil? # On wrong arguments, SketchUp returns nil.
        # Register data.
        AE::Interception::Menu.menu_items << menu
        AE::Interception::Menu.menu_text[menu] = args[0]
      rescue Exception => e
        $stderr.write("Error in ae_LaunchUp/Interception.rb for UI.menu" << $/)
        $stderr.write(e.message << $/)
        $stderr.write(e.backtrace.join($/) << $/)
      ensure
        return menu
      end
    end # unless

  end # class << self

end



unless UI::Command.instance_methods.include?(:proc) || UI::Command.instance_methods.include?("proc")



class UI::Command

  class << self
    unless method_defined?(:new_orig_2d3b68a6)
      alias_method :new_orig_2d3b68a6, :new
      private :new_orig_2d3b68a6

      def new(*args, &block)
        command = new_orig_2d3b68a6(*args, &block)
        return command unless command.is_a?(UI::Command) # On wrong arguments, SketchUp returns nil.
        # Register data.
        AE::Interception::Command.commands << command
        AE::Interception::Command.text[command] = args[0]
        AE::Interception::Command.proc[command] = block
        # Trigger event.
        AE::Interception::Command.listen(:new, command, *args, &block)
      rescue Exception => e
        $stderr.write("Error in ae_LaunchUp/Interception.rb for UI::Command.new" << $/)
        $stderr.write(e.message << $/)
        $stderr.write(e.backtrace.join($/) << $/)
      ensure
        return command
      end
    end # unless
  end # class << self

  unless method_defined?(:set_validation_proc_orig_2d3b68a6)
    alias_method :set_validation_proc_orig_2d3b68a6, :set_validation_proc
    private :set_validation_proc_orig_2d3b68a6

    def set_validation_proc(*args, &block)
      command = set_validation_proc_orig_2d3b68a6(&block)
      return command unless command.is_a?(UI::Command) # On wrong arguments, SketchUp returns nil.
      # Register data.
      AE::Interception::Command.validation_proc[command] = block
      # Trigger event.
      AE::Interception::Command.listen(:set_validation_proc, command, &block)
    rescue Exception => e
      $stderr.write("Error in ae_LaunchUp/Interception.rb for UI::Command.set_validation_proc" << $/)
      $stderr.write(e.message << $/)
      $stderr.write(e.backtrace.join($/) << $/)
    ensure
      return command
    end

  end # unless

end # class UI::Command



end



end # unless file_loaded?
