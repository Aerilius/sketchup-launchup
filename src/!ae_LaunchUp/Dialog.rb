=begin
Permission to use, copy, modify, and distribute this software for
any purpose and without fee is hereby granted, provided that the above
copyright notice appear in all copies.

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

Name:         Dialog.rb
Author:       Andreas Eisenbarth
Description:  Subclass for UI::WebDialog.
              This subclass implements a communication system between Ruby and
              WebDialogs and adds some useful window management functions.
Usage:        Create an instance (with the same arguments as UI::WebDialog):
                  @dlg = Dialog.new(*args)
              Add an event handler when the dialog is shown: (show{} was unreliable in some SketchUp versions)
                  @dlg.on_show{ }
              Add an event handler/callback, that receives any amount of JSON arguments:
                  @dlg.on(String){ |*args| }
              Remove an event handler/callback:
                  @dlg.off(String)
              Call a JavaScript callback from a Ruby callback (synchronously):
                  @dlg.return(data)
              Call a JavaScript callback from outside a Ruby callback (asynchronously):
                  # TODO: There is currently no proper way to get the message id.
                  id = @dlg.instance_variable_get(:@message_id) # in the Ruby callback
                  @dlg.return(data, id)                         # at any time later
              Execute a script now or as soon as the dialog becomes visible:
                  @dlg.execute_script(String)
              Call a public function with JSON arguments:
                  @dlg.call_function(String, *args)

              Window management methods:
              If an argument is nil, that property won't be changed:
                  @dlg.set_size(width, height)
                  @dlg.set_position(left, top)
              Set the dialog's size to fit the HTML content:
                  @dlg.set_client_size
              Set the dialog's position to be centered on the screen:
                  @dlg.set_position_center
              Get the current outer width:
                  @dlg.width
              Get the current outer height:
                  @dlg.height

Requires:     JavaScript modules AE.Bridge and AE.Dialog
              Call AE.Dialog.initialize() at the end of your HTML document.
Version:      1.0.5
Date:         18.05.2013

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



@@reserved_callbacks = ["AE.Bridge.receive_message", "AE.Dialog.initialize", "initialize", "AE.Dialog.adjustSize"]
def initialize(*args)
  # messaging variables
  @procs_callback = {} # Hash of callback_name => Proc
  @procs_show =  []    # Array of Procs
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
  @dialog_visible = false
  @message_id = nil
  @return_data = nil

  if args.length >= 5
    @window_title = args[0].to_s
    @window_width = args[3].to_i if args[3].is_a?(Numeric)
    @window_height = args[4].to_i if args[3].is_a?(Numeric)
  elsif args[0].is_a?(Hash)
    @window_title = args.first[:dialog_title]
    @window_width = args.first[:width].to_i if args.first[:width].is_a?(Numeric)
    @window_height = args.first[:height].to_i if args.first[:height].is_a?(Numeric)
  end

  super(*args)

  # Messaging system with queue, for multiple arguments of any JSON type.
  self.add_action_callback("AE.Bridge.receive_message") { |dlg, param|
    begin
      # Get message id.
      @message_id = param[/\#\d+$/][/\d+/]

      # Eval message data.
      begin
        arguments = eval(param)
      rescue SyntaxError
        raise(ArgumentError, "Dialog received invalid data '#{param}'.")
      end

      # If no other data were received via url, look in hidden input element.
      if arguments.nil?
        arguments = eval(dlg.get_element_value("AE.Bridge.message##{@message_id}"))
      end
      raise(ArgumentError, "Dialog received wrong type of data '#{arguments}'") unless arguments.is_a?(Array)

      # Get callback name.
      name = arguments.shift
      raise(ArgumentError, "Callback '#{name}' for #{dlg} not found.") if name.nil? || !@procs_callback.include?(name)

      # Call the callback.
      begin
        @procs_callback[name].call(dlg, *arguments)
      rescue Exception => e
        # TODO: It could tell JavaScript that there was an error
        raise(e.class, "#{self.class.to_s.gsub(/\:/,'')} Error for callback '#{name}': #{e.message}", e.backtrace)
      else
        # Optionally the Ruby callback can return data to a JavaScript callback.
        if @return_data
          data_string = to_json(@return_data)
          execute_script("AE.Bridge.callbackJS(#{@message_id}, #{data_string})")
          @return_data = nil
        end
      end

    rescue Exception => e
      $stderr.write(e.message << $/)
      $stderr.write(e.backtrace.join($/) << $/)
    ensure
      # Unlock JavaScript to send the next message.
      dlg.execute_script("AE.Bridge.nextMessage()")
      @message_id = nil
    end
  }

  # Get some initial data.
  # This needs to be invoked by doing in JavaScript:
  # AE.Dialog.initialize();
  @procs_callback["AE.Dialog.initialize"] = Proc.new{ |dlg, params|
    w, h, wl, wt, sw, sh = params
    @window_border_width = ((@window_width - w) / 2.0).to_i
    @window_titlebar_height = (@window_height - h).to_i
    @window_left = wl if wl.is_a?(Numeric) && wl > 0
    @window_top = wt if wt.is_a?(Numeric) && wt > 0
    @screen_width = sw if sw.is_a?(Numeric) && sw > 0
    @screen_height = sh if sh.is_a?(Numeric) && sh > 0
    @dialog_visible = true
    # Trigger all event handlers for when the dialog is shown.
    # Output errors because SketchUp's native callback would not output errors.
    @procs_show.each{ |block|
      begin
        block.call(dlg)
      rescue Exception => e
        $stderr.write(e.message << $/)
        $stderr.write(e.backtrace.join($/) << $/)
      end
    }
  }

  # Try to set the default dialog color as background. # TODO Test on Windows 7 and OS X if this is still necessary.
  # This is a workaround because on some systems/browsers the CSS system color is
  # wrong (white), and on some systems SketchUp returns white (also mostly wrong).
  @procs_show << Proc.new{
    color = get_default_dialog_color
    # If it's white, then it is likely not correct and we try the CSS system color instead.
    execute_script("if (!document.body.style.background && !document.body.style.backgroundColor) { document.body.style.backgroundColor = '#{color}'; }") unless color == "#ffffff"
  }

  # We have to make sure the dialog has a size that we know.
  self.set_size(@window_width, @window_height)

  # Adjust the dialog size to the inner size
  @procs_callback["AE.Dialog.adjustSize"] = Proc.new{ |dlg, params|
    next unless @dialog_visible
    w, h, l, t = *params rescue raise("Callback 'AE.Dialg.adjustSize' received invalid data: #{params.inspect}")
    # Calculate the outer window size from the given document size:
    @window_width = (w.to_f + 2 * @window_border_width).to_i
    @window_height = (h.to_f + @window_titlebar_height).to_i
    # Allow the dialog not to exceed the screen size:
    @window_width = [@window_width, @screen_width - l + @window_border_width - 1].min if l.is_a?(Numeric)
    @window_height = [@window_height, @screen_height - t + @window_titlebar_height - 1].min if t.is_a?(Numeric)
    # Set the new size
    if ( Object::RUBY_PLATFORM =~ /darwin/i ) && l.is_a?(Numeric) && t.is_a?(Numeric)
=begin
      dlg.set_size(@window_width, @window_height)
      # If we are on OSX, SketchUp resizes towards the top, changing the dialog's top position.
      # We need to compensate that by enforcing the original position again.
      # In WebKit, window.screenX/Y and window.screenLeft/Top return the outer position
      # of the window, not the client area. So there is no need to subtract the width
      # of the window border or the height of the titlebar.
      left = l
      top = t
      dlg.set_position(left, top)
      # Problem: This causes flickering because the position is set after the dialog resized.
=end
      t1 = Thread.new{
        `osascript <<EOF
        tell application "SketchUp" to activate
        tell application "System Events"
        set wd to "#{@window_width}"
        set ht to "#{@window_height}"
           set the (size) of window ("#{@window_title}") of application process "SketchUp" of application "System Events" to {wd, ht}
        end tell
        EOF`
      }
      t1.kill
    elsif l.is_a?(Numeric) && t.is_a?(Numeric)
      dlg.set_size(@window_width, @window_height)
    end
  }

  # Puts (for debugging)
  @procs_callback["puts"] = Proc.new{ |dlg, param|
    puts(param.inspect)
  }

  # Close the Dialog.
  @procs_callback["AE.Dialog.close"] = Proc.new{ |dlg, param|
    dlg.close
    # Trigger all event handlers for when the dialog is closed.
    # Output errors because SketchUp's native callback would not output errors.
    if @dialog_visible
      @procs_close.each{ |block|
        begin
          block.call(dlg)
        rescue Exception => e
          $stderr.write(e.message << $/)
          $stderr.write(e.backtrace.join($/) << $/)
        end
      }
      @dialog_visible = false
    end
  }
  set_on_close{
    # Trigger all event handlers for when the dialog is closed.
    # Output errors because SketchUp's native callback would not output errors.
    if @dialog_visible
      @procs_close.each{ |block|
        begin
          block.call(self)
        rescue Exception => e
          $stderr.write(e.message << $/)
          $stderr.write(e.backtrace.join($/) << $/)
        end
      }
      @dialog_visible = false
    end
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



# Add event handlers for when the dialog is closed.
# @param [Proc] block to execute when the dialog is closed
def on_close(&block)
  raise(ArgumentError, "Must have a Proc.") unless block_given?
  @procs_close << block
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



# Call a JavaScript function with JSON arguments in the webdialog.
# @param [String] name of a public JavaScript function
# @params [Object] arguments array of JSON-compatible objects
def call_function(name, *arguments)
  arguments.map!{ |arg| to_json(arg) }
  execute_script("#{name}(#{arguments.join(", ")});")
end



# Window management related methods.



# Returns the current dialog outer width.
def width
  return @window_width # outer width
end



# Returns the current dialog outer height.
def height
  return @window_height # outer height
end



# Changes the size of the webdialog to one or both of width and height to the
# given values.
# @param [Numeric,NilClass] w outer width
# @param [Numeric,NilClass] h outer height
def set_size(w=nil, h=nil)
  @window_width = w if w.is_a?(Numeric) && w > 0 # TODO: > min_width
  @window_height = h if h.is_a?(Numeric) && h > 0 # TODO: > min_height
  super(@window_width, @window_height)
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
  sanitize = Proc.new{ |v|
    if v.is_a?(Array)
      new_v = []
      v.each{ |a| new_v << sanitize.call(a) if json_classes.include?(a.class)}
      new_v
    elsif v.is_a?(Hash)
      new_v = {}
      v.each{ |k, w| new_v[k.to_s] = sanitize.call(w) if (k.is_a?(String) || k.is_a?(Symbol)) && json_classes.include?(w.class) }
      new_v
    elsif v.is_a?(Symbol)
      v.to_s
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
  # Replace => and nil.
  json_string = o.inspect.split(/(\"(?:.*?(?:[\\][\\]*?|[^\\]))*?\")/).
    collect{ |s|
      (s[0..0] != '"')?                        # If we are not inside a string
      s.gsub(/\=\>/, ":").                     # Arrow to colon
        gsub(/\bnil\b/, "null") :              # nil to null
      s
    }.join
  return json_string
end



end # class Dialog



end # module LaunchUp



end # module AE
