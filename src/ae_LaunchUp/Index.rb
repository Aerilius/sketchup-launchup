module AE



module LaunchUp



# Translation library.
require(File.join(PATH_ROOT, 'Translate.rb'))
# Load translation strings.
TRANSLATE = Translate.new("LaunchUp", File.join(PATH_ROOT, "lang")) unless defined?(self::TRANSLATE)
# Scorer to judge relevance of strings.
require(File.join(PATH_ROOT, "scorer", "scorer.rb"))



# An index of SketchUp's commands.
#
class Index



  # Make this a singleton class.
  private_class_method :new

  class << self

  def instance
    if @__instance__.nil?
      @__instance__ = self.__send__(:new)
      def instance; return @__instance__; end
    end
    return @__instance__
  end

  end # class << self



  # List of commands with unknown Proc (probably loaded before Interception.rb).
  # For debugging.
  @@missing = []
  def self.missing
    return @@missing
  end



  # Instance methods



  # Create a new instance of the index and fill it with all existing UI::Commands.
  # (from ObjectSpace or – as currently – from intercepted methods.
  # UI::Command will need methods like :proc, :validation_proc, and eventually :name, :description, :menu_path
  #
  def initialize
    @data = [] # TODO: or is {} faster? We have to loop over all elements anyways.
    @total_track = 0

    # Optimization: cache toolbar names in a hash to speed up Index.add()
    # Note: Iterating over toolbars can give a UI::Command or String (separator "|").
    @toolbars = {}
    ObjectSpace.each_object(UI::Toolbar){|toolbar| toolbar.each{|command| @toolbars[command] = toolbar.name} if toolbar.respond_to?(:each)}

    # Load all existing UI::Commands into the index.
    # This would require UI::Command to have the methods (name), proc, validation_proc.
    ObjectSpace.each_object(UI::Command){|command|
      add(command)
    }

    # If new commands are added at run time, we want to get notified so we can
    # add them to this Index.
    @scheduler = Scheduler.new(1)
    AE::Interception::Command.add_listener(:new){|*args|
      command = args[0]
      break unless command.is_a?(UI::Command)
      # Wait until all properties may have been added to the command.
      # TODO: We could also just have intercepted small_icon, tooltip … as well.
      # The scheduler.add is also important because it combines several Procs into
      # one timer, calling too many timers in a short time would crash SketchUp.
      @scheduler.add{
        add(command)
      }
    }

    # TODO: Allow here to plug-in smart searches. Import all files from ./smart-searches.

    # This example allows to load extensions on demand:
    Sketchup.extensions.each{|extension|
      # Maybe we should only add those that are not yet loaded? But then the user can't find them if not knowing that.
      # We need here feature testing, because :loaded?, :load have been added with SU8M2, where as :name, :description, :creator exist since SU6.
      # Another reason is that other plugins could have a custom extension class that is neither subclassed from SketchupExtension nor fully compatible with the installed SketchUp's extension (ie. 3Dconnexion).
      next unless extension.is_a?(SketchupExtension) && extension.respond_to?(:loaded?) && (extension.respond_to?(:loaded?) or extension.respond_to?(:load))
      hash = {
        :name => (extension.loaded?) ? TRANSLATE["Extension %0 already loaded", extension.name] : TRANSLATE["Load extension %0", extension.name],
        :description => extension.description,
        :category => TRANSLATE["Extensions"],
        :keywords => [TRANSLATE["extension"], TRANSLATE["plugin"], TRANSLATE["addon"], extension.creator],
        :proc => Proc.new{|extension| extension.load },
        # The command is enabled as long as the extension is not loaded.
        :validation_proc => extension.loaded? ? Proc.new{ MF_GRAYED } : Proc.new{ (extension.loaded?) ? MF_GRAYED : MF_ENABLED },
        # :no_history => true, # TODO: If it is not added to the history, we need other feedback that it has been loaded.
      }
      add(nil, hash)
    }
  end



  # This adds a new entry to the index.
  # @param [UI::Command] command
  # @param [Hash] hash  with metadata
  #
  # The following metadata is available and overrides those of the UI::Command:
  #   :command [UI::Command] (optional, not used)
  #   :proc [Proc] The code block that executes when a command is called.
  #   :name [String] A title of the command. It should allow the user to identify
  #       the command (unambiguous) and include the significant aspect of this
  #       command (ie. "Unselect groups" instead of "Groups").
  #       It corresponds to the String argument of UI::Command.new, or menu_text.
  #   :description [String] A full phrase or phrases describing what the command does.
  #       It corresponds to status_bar_text or tooltip (but more general-purpose).
  #   :icon [String] An absolute file path to a (png) icon image.
  #   :validation_proc [Proc] (optional) A Proc that returns 0 (MF_ENABLED, MF_UNCHECKED)
  #       if a command can be used in the current context.
  #   :category [String] (optional) A term for grouping the command with others,
  #       ie. the field of application, toolbar name or menu path.
  #   :keywords [Array] (optional) Alternative words and synonyms related to the
  #       command that are not visible from the name/description.
  #   :file [String] (optional) A file path to the most relevant ruby file of a
  #       plugin. (not used so far)
  #
  # Private metadata:
  #   :id [Fixnum] This is a unique hash code that makes commands identifiable
  #       over sessions. (because UI::Command.object_id is lost)
  #   :track [Fixnum] Used to count how often a command was executed. This way we
  #       increase its score can distinguish it from less popular commands.
  #   :score [Float] This holds the score/ranking from the last search.
  #   :enabled [Boolean] Whether the command can be executed in the current context,
  #       obtained from the last result of validation_proc.
  #
  # Since :proc is required for this plugin to work, we add here also intercepted
  # data from AE::Interception. However better would be if the UI::Command exposes
  # proc and validation_proc (and more).
  #
  def add(command=nil, hash={})
    raise(ArgumentError, "Argument 'command' must be a UI::Command.") unless command.is_a?(UI::Command) || command.nil?
    raise(ArgumentError, "Argument 'hash' must be a Hash.") unless hash.is_a?(Hash)
    hash[:command] = command

    # Proc
    hash[:proc] ||= command.respond_to?(:proc) ? command.proc : AE::Interception::Command.proc[command]

    # Validation Proc
    hash[:validation_proc] ||= command.respond_to?(:validation_proc) ? command.validation_proc : AE::Interception::Command.validation_proc[command]

    # Name
    hash[:name] ||= command.respond_to?(:menu_text) ? command.menu_text : AE::Interception::Command.text[command]

    # If we don't get a proc and name, it's useless.
    return @@missing << command unless hash[:proc] && hash[:name]

    # Description
    hash[:description] ||= command.respond_to?(:status_bar_text) ?
      command.status_bar_text || command.tooltip :
      TRANSLATE["LaunchUp requires SketchUp > 8M1 to display more descriptive info."]

    # Icon
    # Note: If developer assigns a relative file path, SketchUp interprets it
    # relative to the file where it has been assigned command.large_icon=() and
    # converts it into an absolute path. So the getter method command.large_icon
    # gets always an absolute path.
    hash[:icon] ||= command.respond_to?(:large_icon) ? command.large_icon || command.small_icon : nil

    # Category
    # A category defines more clearly the context of a command (if the name is unspecific).
    if !hash[:category] && command.respond_to?(:category)
      hash[:category] ||= command.category
    elsif !hash[:category]
      # If not given, we use the menu path or toolbar name.
      # TODO: A nice separator would be Unicode › or 〉 or → , or fallback to ASCII >
      menu_path = AE::Interception::Menu.get_menu_path(command)[0..-2]
      if menu_path.length > 0
        if menu_path.first.nil? || menu_path.first.empty?
          menu_path[0] = TRANSLATE["Context menu"]
        else
          # Ruby scripts have only access to the top-level native menus. Those are
          # given in English (upper/lowercase and optionally ending with s) and need translation.
          menu_path[0] = TRANSLATE[menu_path[0]]
        end
      end
      if !menu_path.nil? && !menu_path.empty?
        hash[:category] ||= menu_path.join(" › ")
      elsif @toolbars[command]
        hash[:category] ||= TRANSLATE[@toolbars[command]]
      end
    end

    # Keywords
    # TODO: We could add here synonyms, translations, synonyms, maybe from a dictionary.
    hash[:keywords] = command.respond_to?(:keywords) ? command.keywords : nil

    # File path
    # Get the file path of where the UI::Command was created. It might be useful info.
    file = hash[:proc].inspect[/[^@]+(?=\:\d+\>)/]
    file = nil if hash[:file] == "(eval)"
    # Making the file path relative to a load path is 400× too slow:
    # file = $:.map{|p| file.sub(p, "") }.min{|s| s.length } unless file.nil?
    hash[:file] = file

    # Create a short id to distinguish it from other commands.
    id = hash_code(hash[:name].to_s + hash[:description].to_s)
    hash[:id] = id

    # Track usage statistics for better ranking
    hash[:track] = 0

    # Add this entry only if it is not already contained.
    # Assume that an existing entry is equivalent and update it.
    if @data.find{ |e| e[:id] == id }
      update(hash)
    else
      @data << hash
    end
    return true
  rescue ArgumentError
    raise
  rescue StandardError
    puts("LaunchUp: Command #{command} could not be added to index.")
    return false
  end



  # This method changes an entry in the index.
  # @params [Hash] hash of new keys and values.
  #     It should have a :id or :command to identify an existing entry in the index.
  # @returns [Boolean] success
  def update(hash)
    # Try to find an existing entry in @data.
    ind = nil
    @data.each_with_index{|v, i| ind = i if(v[:id] == hash[:id] || v[:command] == hash[:command]) }
    return false unless ind
    @data[ind].merge!(hash)
    return true
  end



  # Query the index with a search.
  # @param [String] search_string
  # @return [Array] an array of sorted results of the form:
  #    {:name => …, :description => …, :id => …, :proc => …, :validation_proc => …}
  def look_up(search_string, length=nil)
    raise(ArgumentError, "Argument 'search_string' must be a String") unless search_string.is_a?(String)
    length = 10 if length.nil?
    raise(ArgumentError, "Argument 'length' must be a Fixnum") unless length.is_a?(Fixnum)
    return slice(rank(find(search_string)), length)
  end



  # Get a command by its ID.
  # @param [Fixnum] id
  # @returns [Hash] entry
  def get_by_id(id)
    raise(ArgumentError, "Argument 'id' must be a Fixnum") unless id.is_a?(Fixnum)
    @data.find{|entry| entry[:id] == id }
  end
  alias_method(:[], :get_by_id)



  # Execute a command from the index.
  # @param [Fixnum] id
  # @returns [Boolean] success whether the entry was found and executed.
  def execute(id)
    puts("Index.execute(#{id})") if AE::LaunchUp.debug # DEBUG
    entry = get_by_id(id)
    if entry && entry[:proc].is_a?(Proc)
      success = entry[:proc].call
      success = (success != false && success != 1)
      entry[:track] += 1
      @total_track += 1
      return success
    else
      raise
    end
  rescue LocalJumpError => e
    # Proc contains a "return"?
    puts("Proc of '#{entry[:name]}' (#{entry[:id]}) contains 'return'\n#{e.message.to_s}\n#{e.backtrace.join("\n")}")
    return false
  rescue Exception => e
    # Proc contains other bug.
    puts("Error in proc of '#{entry[:name]}' (#{entry[:id]})\n#{e.message.to_s}\n#{e.backtrace.join("\n")}")
    return false
  end



  # This converts this index (or optionally any other object) into JSON.
  # @params [Hash,Array,String,Numeric,Boolean,NilClass] obj, if not given it takes @data.
  # @returns [String] JSON string
  # @deprecated since we run the search now on the Ruby side.
  def to_json(obj=@data)
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
    json_string = o.inspect.split(/(\"(?:.*?[^\\])*?\")/).
      collect{|s|
        (s[0..0] != '"')?                        # If we are not inside a string
        s.gsub(/\:(\S+?(?=\=>|\s))/, "\"\\1\""). # Symbols to String
          gsub(/\=\>/, ":").                       # Arrow to colon
          gsub(/\bnil\b/, "null") :              # nil to null
        s
      }.join
    return json_string
  end



  # This allows to load tracking data into the index (optional, the index works also without).
  # @params [Hash] tracking a hash of   id => amount of clicks   pairs.
  def load_tracking(tracking)
    @data.each{|hash|
      id = hash[:id]
      track = tracking[id]
      next unless track
      hash[:track] ||= 0
      hash[:track] += track
      @total_track += track
    }
  end



  private



  # Since object_ids are not persistent and commands have long names of varying
  # length, we use a hash function to get short and reproducible identifiers.
  # Tip: Use strings and never objects whose <inspect> value contains the <object_id>.
  # @param [Object] object
  # @param [Fixnum] length  amount of digits
  def adler32(s)
    s = s.inspect unless s.is_a?(String)
    h = 0
    m = 99999
    s.unpack("c*").each{|c| h = (128 * h + c).modulo(m)}
    return h
  end
  alias_method :hash_code, :adler32



  # Searches the index data for matches to the search string.
  # @param [String] search_string
  # @returns [Array] an array of result hashes
  def find(search_string)
    result_array = []
    search_words = search_string.split(/\s+/)

    # Loop over all entries in the index.
    @data.each{|entry|
      begin
        # Check whether this entry matches the search words.
        score = 0
        search_words.each{|search_word|
          next if search_word.empty?

          s = 2 * AE::LaunchUp::Scorer.score(search_word, entry[:name]) if entry[:name].is_a?(String)
          s += AE::LaunchUp::Scorer.score(search_word, entry[:description]) if entry[:description].is_a?(String)
          s += 2 * AE::LaunchUp::Scorer.score(search_word, entry[:category]) if entry[:category].is_a?(String)
          s += exact_matches(search_word, entry[:keywords].join(" "))/(entry[:keywords].length|1).to_f if entry[:keywords].is_a?(Array) && !entry[:keywords].empty?
          s += 2 * AE::LaunchUp::Scorer.score(search_word, entry[:keywords].join(" ")) if entry[:keywords].is_a?(Array)
          s += AE::LaunchUp::Scorer.score( search_word.gsub(/\/\\/, ""), entry[:file].gsub(/\/\\/, "") ) if entry[:file].is_a?(String) # && search_word[/\w[\.\/\\]\w/]

          # Skip if no match has been found.
          break score = 0.0 if s == 0.0
          score += s
        }

        # Tweaks for relevance:
        # Entries with icons match better with users's expectation,
        # urls or "about" rather not.
        score *= 3 if entry[:icon].is_a?(String)
        #score *= 0.5 if entry[:name][/about|paypal/i] || entry[:description][/http/]

        # Check wether the command is available in the current context. We don't
        # want to reject it completely from the search results, so that the user
        # won't miss it in an explicit search will. We give a hint if it's disabled.
        if entry[:validation_proc]
          status = nil
          begin
            status = entry[:validation_proc].call == MF_ENABLED
          rescue LocalJumpError => e
            # Validation proc contains a "return"?
            puts("Validation proc of '#{entry[:name]}' (#{entry[:id]}) contains 'return'\n#{e.message.to_s}\n#{e.backtrace.join("\n")}")
          rescue Exception => e
            # Validation proc contains other bug.
            puts("Error in validation proc of '#{entry[:name]}' (#{entry[:id]})\n#{e.message.to_s}\n#{e.backtrace.join("\n")}")
          end
          entry[:enabled] = status
          score *= 0.5 if status == false
        end

        # Skip if no match has been found.
        next if score <= 1.0

        # Consider tracking data, how often this entry has been selected over others:
        score += [10 * entry[:track] / (@total_track|1).to_f, 2.0].min if entry[:track]
        entry[:score] = score

        # Add it to results.
        result_array << entry
      rescue Exception => e
        puts("AE::LaunchUp::Index: Error in 'find' when searching '#{entry[:name]}' (#{entry[:id]})\n#{e.message.to_s}\n#{e.backtrace.join("\n")}")
        break
      end
    }

    return result_array
  rescue Exception => e
    puts("AE::LaunchUp::Index: Error in 'find' when searching '#{search_string}'\n#{e.message.to_s}\n#{e.backtrace.join("\n")}")
    return []
  end



  # Ranks and sorts the results by evaluating how much the entries are relevant for the search string.
  # @param [Array] result_array
  # @returns [Array] sorted array
  def rank(result_array)
    # Highest first.
    return result_array.sort_by{|hash| - hash[:score] + (hash[:enabled]==false ? 10 : 0) }
  end



  # Reduces the results to a maximum amount (from option).
  # @param [Array] result_array
  # @param [Fixnum] length the maximum number of results
  # @returns [Array] reduced array
  def slice(result_array, max_length=10)
    return result_array[0...max_length]
  end



  # These String comparison algorithms were used before I added scorer.rb.
  # They could still be useful.



  # Find the number of exact matches.
  # @param [String] search_word
  # @param [String] string
  def exact_matches(search_word, string)
    regexp = Regexp.new(search_word, "i")
    return (string.scan(regexp) || []).length
  end



  # Find the number of exact matches.
  # Benchmark: 0.132
  # @param [String] search_word
  # @param [String] string
  def exact_match_length(search_word, string)
    regexp = Regexp.new(search_word, "i")
    return ((string.scan(regexp) || [""]).map{|s| s.length}.first || 0) / search_word.length
  end



  # Find the number of exact matches.
  # Benchmark: 0.398
  # @param [String] search_word
  # @param [String] string
  def exact_beginning_length(search_word, string)
    regexp = Regexp.new("(?:\\b" + search_word.gsub(/(?!^)./, "\\0?") + ")", "i")
    return ((string.scan(regexp) || [""]).max{|a, b| a.length <=> b.length} || 0) / search_word.length
  end



  # The Levenshtein algorithm counts the number of operations (insertions,
  # substitutions, deletions) necessary to turn one string into another.
  # @param [String] str1
  # @param [String] str2
  # @returns [Fixnum] Levenshtein distance between the two strings
  def levenshtein(str1, str2)
    m = str1.length
    n = str2.length
    return m if n == 0
    return n if m == 0
    d = Array.new(m+1) {Array.new(n+1)}
    (0..m).each {|i| d[i][0] = i}
    (0..n).each {|j| d[0][j] = j}
    (1..n).each do |j|
      (1..m).each do |i|
        d[i][j] = if str1[i-1] == str2[j-1] # adjust index into string
                    d[i-1][j-1]       # no operation required
                  else
                    [ d[i-1][j]+1,    # deletion
                      d[i][j-1]+1,    # insertion
                      d[i-1][j-1]+1,  # substitution
                    ].min
                  end
      end
    end
    return d[m][n]
  end



  # Relative Levenshtein algorithm. This version ignores different string lengths.
  # It is perfect to check for similar substrings.
  # Benchmark: 2.368
  # @param [String] str1
  # @param [String] str2
  # @returns [Float] between 0 (identical) and 1 (completely different)
  def rlevenshtein(str1, str2)
    return 0 if (str1 == "" || str2 == "")
    return ([str1.length, str2.length].max - levenshtein(str1, str2)) / [str1.length, str2.length].min.to_f
  end



  # Returns an array of pairs of neighbouring characters.
  # @param [String] string
  # @returns [Array] array of pairs of neighbouring characters
  def get_bigrams(string)
    s = string.downcase
    v = []
    (s.length-1).times{|i|
      v[i] = s[i...i+2]
    }
    return v
  end



  # Perform bigram comparison between two strings and return a percentage match.
  # Benchmark: 0.466
  # @param [String] str1
  # @param [String] str2
  # @returns [Float]
  def common_neighbours(str1, str2)
    pairs1 = get_bigrams(str1)
    pairs2 = get_bigrams(str2)
    union = pairs1.length + pairs2.length;
    hit_count = 0
    pairs1.each{|pair1|
      pairs2.each{|pair2|
        hit_count += 1 if pair1 == pair2
      }
    }
    #return (2.0 * hit_count) / union.to_f
    return ((2.0 * hit_count) / union.to_f) / [str1.length, str2.length].min.to_f # -1)
  end



  # Find the longest common substring between two strings.
  # Benchmark: 1.636
  # @param [String] str1
  # @param [String] str2
  # @returns [Fixnum] length of the longest common substring
  def longest_common_substr_length(str1, str2)
    return 0 if (str1 == "" || str2 == "")
    return "" if (str1 == "" || str2 == "")
    m = Array.new(str1.length){ [0] * str2.length }
    longest_length, longest_end_pos = 0,0
    (0 .. str1.length - 1).each{|x|
      (0 .. str2.length - 1).each{|y|
        if str1[x] == str2[y]
          m[x][y] = 1
          if (x > 0 && y > 0)
            m[x][y] += m[x-1][y-1]
          end
          if m[x][y] > longest_length
            longest_length = m[x][y]
            longest_end_pos = x
          end
        end
      }
    }
    return longest_length / [str1.length, str2.length].min.to_f
    return s1[longest_end_pos - longest_length + 1 .. longest_end_pos]
  end



end # module Index



# class Scheduler:
# This class (to be instanced) makes sure given functions are not called more
# frequently than a certain time limit.
# .queue(Proc)
#     Adds a new Proc. All collected Procs will be executed one by one with time interval inbetween.
# .add(Proc)
#     Adds a new Proc to a group of Procs. All collected Procs will be executed at once.
# .replace(Proc)
#     Adds a new Proc to be executed instead of the last Proc. This pattern allows
#     to update actions, ie. with more up-to-date data or redrawing something etc.
#
class Scheduler

  def initialize(dt)
    @scheduled = [] # Array of scheduled procs.
    @t = nil # Tracks the time of the last function call.
    @dt ||= 0.250 # Minimum time interval in seconds between subsequent function calls.
  end

  def queue(&block)
    @scheduled << block
    check
  end

  def add(&block)
    if @scheduled.empty?
      @scheduled << [block]
    elsif @scheduled.last.is_a?(Proc)
      block0 = @scheduled.pop
      @scheduled << [block0, block]
    else
      @scheduled.last << block
    end
    @scheduled << block
    check
  end

  def replace(&block)
    @scheduled.pop unless @scheduled.empty?
    @scheduled << block
    check
  end

  private

  def run
    to_run = @scheduled.shift
    if to_run.is_a?(Proc)
      to_run.call
    else # Array
      to_run.each{|block| block.call }
    end
  end

  def check
    c = Time.now.to_f
    if @t.nil? || c > @t
      # Last function call is long enough ago (or first time), execute given function immediately.
      run
      # Set timer for next possible function call.
      @t = c + @dt
      UI.start_timer(@dt){ run }
    end
  end

end



end # module LaunchUp



end # module AE
