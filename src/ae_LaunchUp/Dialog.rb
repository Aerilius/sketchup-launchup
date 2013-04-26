=begin
Subclass of UI::WebDialog
requires:
JavaScript modules AE.Bridge, AE.Dialog
HTML file that calls skp:initialize or AE.Bridge.callRuby("initialize")
=end

module AE



module LaunchUp



# A subclass of UI::WebDialog.
class Dialog < UI::WebDialog



# Give a short string for inspection. This does not output instance variables
# since these contain a lot of data, references to other objects and self-references.
#
# @return [String] the instance's class and object id
def inspect
  return "#<#{self.class}:0x#{(self.object_id << 1).to_s(16)}>"
end



@@reserved_callbacks = ["AE.Dialog.receive_message", "AE.Dialog.initialize", "initialize", "AE.Dialog.adjustSize"]
def initialize(*args)
  # messaging variables
  @procs_callback = {} # Hash of callback_name => Proc
  @procs_show = []     # Array of Procs
  @procs_close = []    # Array of Procs

  # window management variables
  @window_width = 250 # outer width
  @window_height = 250 # outer height
  @window_border_width = 0
  @window_titlebar_height = 0
  @window_left = 0
  @window_top = 0
  @screen_width = 1200
  @screen_height = 800
  @dialog_initialized = false
  @message_id = nil

  super(*args)

  # Get initial data.
  self.add_action_callback("initialize") {|dlg, param|
    # next if @dialog_initialized # TODO: by disabling this we prevent damage when reloading with F5.
    # Trigger all event handlers for when the dialog is shown.
    @procs_show.each{|block| block.call(dlg) }
  }
  @procs_callback["initialize"] = Proc.new{|dlg, param|
    # next if @dialog_initialized
    # Trigger all event handlers for when the dialog is shown.
    @procs_show.each{|block| block.call(dlg) }
  }

  # Messaging system with queue, multiple arguments of any JSON type
  self.add_action_callback("AE.Dialog.receive_message") { |dlg, param|
    @message_id = param[/\#\d+$/][/\d+/]
    begin
      arguments = eval(param)
    rescue SyntaxError
      []
    end
    name = arguments.shift
    raise("Callback '#{name}' for #{dlg} not found.") if name.nil? || !@procs_callback.include?(name)

    begin
      @procs_callback[name].call(dlg, *arguments)
    rescue Exception => e
      # TODO: It could tell JavaScript that there was an error
      # At least, unlock to send next message.
      puts("Error in callback AE.Dialog.receive_message(#{name}): "+e.message) if $VERBOSE
      next dlg.execute_script("AE.Bridge.nextMessage()")
    else
      # Tell JavaScript it can send the next message. TODO: should we call the nextMessage before executing a synchronous callback?
      dlg.execute_script("AE.Bridge.nextMessage()")
      # Optionally the Ruby callback can return data to a JavaScript callback.
      if @return_data
        data_string = self.to_json(@return_data)
        execute_script("AE.Bridge.callbackJS(#{@message_id}, #{data_string})")
        @return_data = nil
      end
      next
    end
  }

  # Get some initial data.
  @procs_callback["AE.Dialog.initialize"] = Proc.new{|dlg, params|
    next if @dialog_initialized
    w, h, wl, wt, sw, sh = params
    @window_border_width = (@window_width - w.to_f) / 2
    @window_titlebar_height = @window_height - h.to_f
    @window_left = wl if wl.is_a?(Numeric) && wl > 0
    @window_top = wt if wt.is_a?(Numeric) && wt > 0
    @screen_width = sw if sw.is_a?(Numeric) && sw > 0
    @screen_height = sh if sh.is_a?(Numeric) && sh > 0
    @dialog_initialized = true
  }
  # We have to make sure the dialog has a size that we know.
  self.set_size(@window_width, @window_height)
  self.on_show{|dlg|
    dlg.execute_script("AE.Dialog.initialize();")
  }

  # Adjust the dialog size to the inner size
  @procs_callback["AE.Dialog.adjustSize"] = Proc.new{|dlg, param|
    next unless @dialog_initialized
    w, h, l, t = *param rescue raise("Callback 'AE.Dialg.adjustSize' received invalid data: #{param.inspect}")
    # Calculate the outer window size from the given document size:
    @window_width = w.to_f + 2 * @window_border_width
    @window_height = h.to_f + @window_titlebar_height
    # Allow the dialog not to exceed the screen size:
    @window_width = [@window_width, @screen_width - l + @window_border_width - 1].min if l.is_a?(Numeric)
    @window_height = [@window_height, @screen_height - t + @window_titlebar_height - 1].min if t.is_a?(Numeric)
    # Set the new size
    dlg.set_size(@window_width, @window_height)
    # If we are on OSX, SketchUp resizes towards the top, changing the dialog's top position.
    # We need to compensate that by enforcing the original position again.
    # In WebKit, window.screenX/Y and window.screenLeft/Top return the outer position
    # of the window, not the client area. So there is no need to subtract the width
    # of the window border or the height of the titlebar.
    if OSX && l.is_a?(Numeric) && t.is_a?(Numeric)
      left = l
      top = t
      dlg.set_position(left, top)
    end
  }

  # Puts (for debugging)
  @procs_callback["puts"] = Proc.new{|dlg, param| puts(param.inspect) }

  # Close the Dialog.
  @procs_callback["AE.Dialog.close"] = Proc.new{|dlg, param|
    dlg.close
  }
end



# Messaging related methods.



# Returns data back to a JavaScript function.
# For a synchronous callback, it just marks the return data end lets the Ruby proc
# finish (and then it returns the data).
# For an asynchronous callback, the proc has already ended, so this method calls
# JavaScript with a message identifier
# @param [Object] data
# @param [Fixnum] id to identify the JavaScript callback,
#   if not given, it is assumed that it is the current message.
def return(data, id=nil)
  if id && id != @message_id
    data_string = self.to_json(data)
    execute_script("AE.Bridge.callbackJS(#{id}, #{data_string})")
  else
    @return_data = data
  end
end



# Add a callback handler.
# @param [String] callback_name
# @param [Proc] block
def on(callback_name, &block)
  raise(ArgumentError, "Argument 'callback_name' must be a String.") unless callback_name.is_a?(String)
  raise(ArgumentError, "Argument 'callback_name' can not be '#{callback_name}'.") if @@reserved_callbacks.include?(callback_name)
  raise(ArgumentError, "Must have a Proc.") unless block_given?
  @procs_callback[callback_name] = block
  return self
end



# Remove a callback handler.
# @param [String] callback_name
def off(callback_name)
  raise(ArgumentError, "Argument 'callback_name' must be a String.") unless callback_name.is_a?(String)
  @procs_callback.delete(callback_name)
  return self
end



# Add event handlers for when the dialog is shown.
# @param [Proc] block to execute when the dialog becomes visible
def on_show(&block)
  raise(ArgumentError, "Must have a Proc.") unless block_given?
  @procs_show << block
  return self
end



# Execute JavaScript in the webdialog.
# TODO: this should do cleanup of inserted script elements.
# TODO: test why try/catch failed
# @param [String] code_string of JavaScript code
def execute_script(code_string)
  if self.visible?
    super(code_string) # ("try{ eval(#{code_string.inspect}) } catch(e){ AE.Bridge.puts(\"Error in #{caller.first.inspect.inspect[3...-3]} \" + e) }")
  else
    self.on_show{
      self.execute_script(code_string)
    }
    false # TODO: should the method return a boolean at all? It would execute the script anyways.
  end
end



# Window management related methods.



# Changes the size of the webdialog to one or both of width and height to the
# given values.
# @param [Numeric,NilClass] w outer width
# @param [Numeric,NilClass] h outer height
def set_size(w=nil, h=nil)
  @window_width = w ||= @window_width
  @window_height = h ||= @window_height
  super(w, h)
end



# Changes the size of the webdialog to fit its content. This method first calls
# JavaScript which calls back to Ruby.
def set_client_size
  if self.visible?
    self.execute_script("AE.Dialog.adjustSize();")
  else
    self.on_show{
      self.execute_script("AE.Dialog.adjustSize();")
    }
  end
end



# Changes the position of the webdialog to on or both of left and top t the given values.
# @param [Numeric,NilClass] l distance fro left
# @param [Numeric,NilClass] t distance from top
def set_position(l=nil, t=nil)
  @window_left = l ||= @window_left
  @window_top = t ||= @window_top
  super(l, t)
  return self
end



# Changes the position of the webdialog to be in the center if the screen.
# TODO: How does this work on multi-monitor setup?
def set_position_center
  self.set_position(0.5*(@screen_width-@window_width), 0.5*(@screen_height-@window_height))
  return self
end



=begin
def update_geometry
  if self.visible?
    return self.execute_script("AE.Bridge.callRuby('get_geometry', AE.Dialog.get_geometry());")
  end
end
private :update_geometry


def set_size
# on OSX, also call set_position
  super
  return self
end


def get_size
end


def get_inner_size
end


def set_position
  return self
end


def set_inner_position
  return self
end


def get_position
  return [@window_left, @window_top]
end


def get_inner_position
  l = @window_left + @window_border_width
  t = @window_top + @window_titlebar_height
  return [l, t]
end
=end



# This converts Ruby objects into JSON.
# @params [Hash,Array,String,Numeric,Boolean,NilClass] obj
# @returns [String] JSON string
# @deprecated since we run the search now on the Ruby side.
def to_json(obj)
  json_classes = [String, Symbol, Fixnum, Float, Array, Hash, TrueClass, FalseClass, NilClass]
  # Remove non-JSON objects.
  sanitize = nil
  sanitize = Proc.new{|v|
    if v.is_a?(Array)
      new_v = []
      v.each{|a| new_v << sanitize.call(a) if json_classes.include?(a.class)}
      new_v
    elsif v.is_a?(Hash)
      new_v = {}
      v.each{|c, w| new_v[c] = sanitize.call(w) if (c.is_a?(String) || c.is_a?(Symbol)) && json_classes.include?(w.class) }
      new_v
    else
      v
    end
  }
  if json_classes.include?(obj.class)
    o = sanitize.call(obj)
  else
    return "null"
  end
  # Split at every even number of unescaped quotes. This gives either strings
  # or what is between strings.
  # If it's not a string then turn Symbols into String and replace => and nil.
  json_string = o.inspect.split(/(\"(?:.*?(?:[\\][\\]*?|[^\\]))*?\")/).
    collect{|s|
      (s[0..0] != '"')?                        # If we are not inside a string
      s.gsub(/\:(\S+?(?=\=>|\s))/, "\"\\1\""). # Symbols to String
        gsub(/\=\>/, ":").                       # Arrow to colon
        gsub(/\bnil\b/, "null") :              # nil to null
      s
    }.join
  return json_string
end



end # class Dialog



end # module LaunchUp



end # module AE
