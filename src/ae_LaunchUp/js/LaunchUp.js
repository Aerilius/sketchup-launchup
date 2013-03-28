/* module LaunchUp:
   Methods for the SketchUp plugin LaunchUp.

Library summary:
module AE
  module LaunchUp
    Options
    .initialize(hash)                    // Initializes the UI with data/settings from a hash.
    module ComboBox                      // A search field widget with suggestions.
      .initialize(input, list)
      .focus                             // Give focus to the input field.
      .reset                             // Resets the suggestions and clears the input field.
    module Index                         // Deprecated: This is now all don in Ruby.
      .load(array of entries)
      .look_up(String)
      .execute(id)
    module History                      // A list of previously executed commands.
      .initialize(element)
      .load(aray)
      .add(entry)
      .show                             // Shows the History after hiding it temporarily.
      .hide                             // Hides the History temporarily.
      .on                               // Turns the History on (and changes the option).
      .off                              // Turns the History off (and changes the option).
 */



AE.LaunchUp = function(LaunchUp) {



// Short handle for selector function.
var $ = AE.$;

// Object to hold options.
var Options = LaunchUp.Options = {};



LaunchUp.initialize = function(opt) {
  // Load the options.
  if (!opt) { opt = {} }
  for (var i in opt) { Options[i] = opt[i] }
  if (Options.debug) { AE.debug = Options.debug }

  // Initialize the Dialog module.
  AE.Dialog.initialize();

  // Set the background color.
  LaunchUp.updateColors();

  // Initialize the combobox.
  ComboBox.initialize($("#combo_input"), $("#combo_list"));

  // Initialize the list that keeps track of the command history.
  History.initialize($("#history"));

  // Initialize buttons.
  var buttonPin = $("#button_pin");
  buttonPin.toggle = function(bool) {
    if (bool === true || bool === false) { Options.pinned = bool }
    else { bool = Options.pinned = !Options.pinned };
    AE.Bridge.updateOptions({pinned: bool});
    buttonPin.title = (bool) ?
    AE.Translate.get("Pinned. \nLaunchUp stays always visible. \nClick to change.") :
    AE.Translate.get("Unpinned. \nLaunchUp hides always after executing \na command. Click to change.");
    AE.Style.removeClass(buttonPin, bool ? "off" : "on");
    AE.Style.addClass(buttonPin, bool ? "on" : "off");
    ComboBox.focus();
  };
  buttonPin.onmouseup = buttonPin.toggle;
  buttonPin.toggle(Options.pinned); // Set the default.

  var buttonHistory = $("#button_history");
  buttonHistory.toggle = function(bool) {
    if (bool !== true && bool !== false) { bool = Options.show_history = !Options.show_history };
    AE.Style.removeClass(buttonHistory, bool ? "off" : "on");
    AE.Style.addClass(buttonHistory, bool ? "on" : "off");
    bool ? History.on() : History.off();
    ComboBox.focus();
  };
  buttonHistory.onmouseup = buttonHistory.toggle;
  buttonHistory.toggle(Options.show_history); // Set the default.

  // We load recent entries only now after initializing the history button so
  // that the on/off status is already set.
  AE.Bridge.callRuby("get_entries", Options.history_entries, function(array) {
    History.load(array);
  });

  /* Problem:
   * 1.) Internet Explorer has a different implementation of the window.onfocus/onblur
   *     events and triggers onblur when an element inside the window takes focus.
   *     Internet Explorer uses onfocusin/onfocusout instead.
   * 2.) When SketchUp's UI::WebDialg is resized, it gets focus and triggers a
   *     cascade of events (focus, blur...). This utility function Dialog.addOnFocus
   *     filters out unnecessary events.
   */
  AE.Dialog.addOnFocus(function() {
    ComboBox.focus();
  });

  AE.Dialog.addOnBlur(function() {
    ComboBox.reset();
    History.show();
  });

  // Adjust the size (height) when the dialog has been manually resized.
  // On Windows it requires a little delay to complete resizing because it triggers
  // onresize twice (for height & width). Otherwise we would use incorrect
  // dimensions and the dialog flickers.
  window.onresize = function(){window.setTimeout(AE.Dialog.adjustSize, 0)};

  // Workaround: No idea why it hasn't already adjusted the size in time.
  if (AE.PLATFORM == "OSX") { window.setTimeout(AE.Dialog.adjustSize, 250); window.setTimeout(AE.Dialog.adjustSize, 500); }

  // Load the index from ruby.
  // @deprecated
  if (Options.local_index) { AE.Bridge.callRuby("load_index"); }
};



LaunchUp.updateColors = function() {
  var color = (Options.color !== "custom") ? Options.color : Options.color_custom;
  if (color) { document.getElementsByTagName('body')[0].style.backgroundColor = color; }
  // Set the text color.
  var text_color = {
    "ButtonFace": "ButtonText",
    "Menu": "MenuText",
    "Window": "WindowText",
    "ActiveCaption": "CaptionText",
    "InactiveCaption": "InactiveCaptionText",
    "custom": Options.color_custom_text
  }[Options.color]
  if (text_color) document.getElementsByTagName('body')[0].style.color = text_color;
}



/* module ComboBox:
 * Methods to interact with the Webdialog or Ruby.
 */
var ComboBox = LaunchUp.ComboBox = function(self) {

  // Private variables.
  var INPUT = null;
  var LIST = null;
  var DEFAULT_SEARCH_TEXT = "Search…";
  var DEFAULT_OVERLAY = null;
  var INPUT_TEXT = ""; // This variable keeps a copy of the original text that has been typed into the input field.
  var MIN_LENGTH = 0; // Minimum length of input before search starts.
  var SELECTED = -1; // Index of selected entry in dropdown list. (This is not a DATA id.)
  var SCHEDULER = new AE.Scheduler(500); // Allows to reduce too frequent search requests to 1 per 500ms.
  var STYLE = "wide";
  var setDefaultText; // Function to set the default text.

  // Public methods.

  self.initialize = function(input, list) {
    INPUT = input;
    LIST = list;
    if (!Options.style_suggestions) { Options.style_suggestions = STYLE }
    else { STYLE = Options.style_suggestions }
    AE.Style.addClass(LIST, Options.style_suggestions);

    // Create default text.
    DEFAULT_SEARCH_TEXT = AE.Translate.get("Search…");
    ERROR_TEXT = AE.Translate.get("Error: Command was not executed.");
    if ('placeholder' in INPUT) { // HTML5
      INPUT.placeholder = DEFAULT_SEARCH_TEXT;
      setDefaultText = function(text) {
        INPUT.placeholder = text;
      };
    } else { // Fallback: Create overlay element.
      DEFAULT_OVERLAY_CONTENT = document.createElement("div");
      DEFAULT_OVERLAY_CONTENT.className = "default-text";
      DEFAULT_OVERLAY_CONTENT = document.createElement("span");
      DEFAULT_OVERLAY_CONTENT.style.whiteSpace = "nowrap";
      DEFAULT_OVERLAY_CONTENT.appendChild( document.createTextNode(DEFAULT_SEARCH_TEXT) );
      DEFAULT_OVERLAY = document.createElement("span");
      DEFAULT_OVERLAY.onselectstart = function(){return false;};
      DEFAULT_OVERLAY.unselectable = "on";
      DEFAULT_OVERLAY.style.width = 0;
      DEFAULT_OVERLAY.style.height = 0;
      DEFAULT_OVERLAY.style.display = "inline-block";
      DEFAULT_OVERLAY.style.overflow = "visible";
      DEFAULT_OVERLAY.style.position = "relative";
      DEFAULT_OVERLAY.style.verticalAlign = "-5%";
      DEFAULT_OVERLAY.style.textIndent = "0.75em";
      INPUT.parentNode.insertBefore(DEFAULT_OVERLAY, INPUT);
      DEFAULT_OVERLAY.appendChild(DEFAULT_OVERLAY_CONTENT);
      // Make the overlay click-through.
      DEFAULT_OVERLAY.onmousedown = self.focus;
      setDefaultText = function(text) {
        DEFAULT_OVERLAY_CONTENT.innerHTML = text;
      };
    }

    // Attach event handlers.

    // Keyboard events.
    INPUT.onkeyup = function(event) {
      if (window.event) { var keycode = window.event.keyCode }
      else if (event) { var keycode = event.which };

      // arrow down: Select next entry.
      if (keycode == 40) {
        select(SELECTED + 1);
      }
      // arrow up: Select previous entry.
      else if (keycode == 38) {
        select(SELECTED - 1);
      }
      // enter key: Execute first entry.
      else if ( keycode == 13 && LIST.getElementsByTagName("li").length > 0 ) {
        if (SELECTED == -1) { select(0) };
        submit();
      }
      // other keys
      else {
        // To prevent complete searches at every key event, we use a scheduler to limit them to a minimum interval.
        SCHEDULER.replace(function() {
          SELECTED = -1;
          INPUT_TEXT = INPUT.value;
          if (INPUT_TEXT == "") {
            emptyList();
            AE.Style.show(DEFAULT_OVERLAY);
          } else if (INPUT_TEXT.replace(/^\s+|\s+$/g, "").length > MIN_LENGTH) {
            AE.Style.hide(DEFAULT_OVERLAY);
            if (Options.local_index) { // @deprecated
              results = Index.look_up(INPUT_TEXT);
              rebuild(results);
            } else {
              AE.Bridge.callRuby("look_up", INPUT_TEXT, function(results){ rebuild(results) } );
            };
          }
        });
      }
    };

    // Important: If we set focus, then with delay, otherwise NS_ERROR_XPC_BAD_CONVERT_JS error.
    // window.setTimeout(INPUT.focus, 0);
  };

  /* Set the style of the list items. */
  self.updateStyle = function() {
    if (Options.style_suggestions === STYLE) { return; }
    AE.Style.removeClass(LIST, STYLE);
    AE.Style.addClass(LIST, Options.style_suggestions);
    STYLE = Options.style_suggestions;
    AE.Dialog.adjustSize();
  };

  /* Select an entry to highlight it and mark it for submission. */
  var select = function(newSelected) {
    var listItems = LIST.getElementsByTagName("li");
    // Unmark current selection.
    if (SELECTED > -1 && SELECTED < listItems.length) {
      AE.Style.removeClass(listItems[SELECTED], "selected");
    }
    // Switch selection.
    if (newSelected >= -1 && newSelected <= listItems.length) {
      // Check that the new item is selectable (entry.enabled not false).
      var direction = (newSelected > SELECTED) ? 1 : -1;
      while (listItems[newSelected] && listItems[newSelected].entry && listItems[newSelected].entry.enabled === false) { newSelected += direction }
      SELECTED = newSelected;
    }
    // Mark new selection and copy text to input field.
    if (SELECTED >- 1 && SELECTED < listItems.length) {
      AE.Style.addClass(listItems[SELECTED], "selected");
      INPUT.value = listItems[SELECTED].entry.name;
    }
    // If we go from a selected entry back to no selection (-1), restore the original input.
    else {
      INPUT.value = INPUT_TEXT;
    }
  };

  /* Submit a selected entry to whatever function is defined here. */
  var submit = function(entry) {
    if (typeof entry != "number") {
      if (LIST.getElementsByTagName("li")[SELECTED]) {
        var entry = LIST.getElementsByTagName("li")[SELECTED].entry;
      } //else { return; }
    }
    self.reset();
    // Execute the command after the ComboBox has been reset. Reset causes the
    // dialog to resize and SketchUp gives the dialog focus, removing focus from
    // the selected tool / VCB / other dialog.
    window.setTimeout(function(){
      if (Options.local_index) {
        Index.execute(entry.id);
        History.add(entry);
        if (Options.pinned) { Dialog.close() }
      } else {
        if (AE.debug) { AE.Bridge.puts("ComboBox.submit("+entry.id+")") } // DEBUG
        AE.Bridge.callRuby("execute", entry.id, function(success){
          if (AE.debug) { AE.Bridge.puts("ComboBox.submit: Command "+entry.id+" was executed: "+success) } // DEBUG
          // Success: continue.
          if (success === true) {
            History.add(entry);
            if (Options.pinned===false) { AE.Dialog.close() }
          }
          // Failure: Show error message.
          else {
            setDefaultText(ERROR_TEXT);
            window.setTimeout(function(){ setDefaultText(DEFAULT_SEARCH_TEXT) }, 5000)
          };
        });
      };
    }, 0);
  };

  /* Clear the input field. */
  var emptyInput = function() {
    INPUT_TEXT = "";
    INPUT.value = "";
  };

  /* Clear the list. */
  var emptyList = function() {
    SELECTED = -1;
    LIST.innerHTML = "";
    History.show();
    AE.Dialog.adjustSize();
  };

  /* Focus the input field. */
  self.focus = function() {
    INPUT.focus();
  };

  /* Focus the input field. */
  self.reset = function() {
    emptyInput();
    AE.Style.show(DEFAULT_OVERLAY);
    emptyList();
    INPUT.blur();
  };

  /* Build the suggestion list. */
  var rebuild = function(results) {
    if (!results) results = [];
    // Empty the results in the combo-list element.
    LIST.innerHTML = "";
    SELECTED = -1;
    (History && results.length > 0) ? History.hide() : History.show();
    // Generate an entry for each result.
    for (var i=0; i<results.length; i++) {
      // Container element(s)
      var entry = results[i];
      if (typeof(entry)==="undefined" || entry === null) { continue; }
      var div = document.createElement("div");
      var li = null;
      var li = document.createElement("li");
        li.setAttribute("id", "entry_" + entry.id);
        li.setAttribute("title", entry.description||entry.name||"" );
        li.appendChild(div);
        li.entry = entry;
        // If the entry is enabled (or no such info known), its action can be executed.
        if (entry.enabled !== false) {
          li.onclick = function() {
            if (AE.debug) { AE.Bridge.puts("Clicked on "+this.entry.id) }; // DEBUG
            submit(this.entry);
          }
        // Otherwise show it grayed.
        } else {
          li.setAttribute("class", "grayed");
          // Allow to add the entry to the History (as dynamic toolbar), although it can't be used now but for later.
          li.onclick = function() {
            History.add(this.entry);
          }
        };
      // Icon for the command.
      if (typeof(entry.icon) !== "undefined" && entry.icon !== null && entry.icon !== "") {
        var img = document.createElement("img");
        img.setAttribute("src", entry.icon);
        div.appendChild(img);
      };
      if (AE.debug) { // DEBUG
        // Score (for debugging correct order).
        div.appendChild(
          document.createElement("span").appendChild(
            document.createTextNode( "#"+entry.id )));
        // ID (for debugging).
        div.appendChild(
          document.createElement("span").appendChild(
            document.createTextNode( " ("+(Math.round(100*entry.score)/100)+") " )));
        // More debug infos.
        if (entry.dbg_info) {
          div.appendChild(
            document.createElement("span").appendChild(
              document.createTextNode( " "+entry.dbg_info+" " )));
        };
      };
      // Name of the command.
      var span = document.createElement("span");
      span.setAttribute("class", "name");
      span.appendChild(
        document.createTextNode(entry.name||""));
      div.appendChild(span);
      // Category of the command.
      if (entry.category) {
        var span = document.createElement("span");
        span.setAttribute("class", "category");
        span.appendChild(
          document.createTextNode(" "+entry.category));
        div.appendChild(span);
      }
      // Description of the command.
      if (AE.debug && typeof entry.dbg_info !== "undefined" && entry.dbg_info !== null) { entry.description = entry.dbg_info + " " + entry.description } // DEBUG, TODO: remove this.
      if (entry.description !== entry.name && entry.enabled !== false) {
        var span = document.createElement("span");
        span.setAttribute("class", "description");
        span.appendChild(
          document.createTextNode(" "+entry.description||""));
        div.appendChild(span);
      }
      // Attach the entry into the DOM.
      LIST.appendChild(li);
    }
    AE.Dialog.adjustSize();
  };

  return self;
}(LaunchUp.ComboBox || {}); // end module ComboBox



/* module Index:
 * A local search index. This was for testing whether a search in JavaScript is
 * faster/slower that communicating every search request to Ruby and back and
 * with Ruby's slow string performance.
 * @deprecated
 */
var Index = LaunchUp.Index = function(self) {

  // Private variables.
  var DATA = [];

  // Public methods.

  /* Load new data into the index from Ruby. */
  self.load = function(array) {
    DATA = array;
  };

  // The general search function.
  self.look_up = function(search_string) {
    // DEBUG: dummy data, can be removed.
    // return [{"id": 0, "name": "Tool", "description": "This Tool does something.", "icon": "/path/to/image.png", "file": "/path/to/file.rb"}];
    // return [{id:1,name:"Scale",description:"The Scale Tool makes things bigger.",category:"Tools",icon:"../commands/Scale_LG.png"},{id:2,name:"Rotate",description:"The Rotate Tool turns things around.",category:"Tools",icon:"../commands/Rotate_LG.png"},{id:3,name:"Resize Textures",description:"Texture Resizer can reduce and optimize the size of textures in the model.",category:"Plugins > Texture Resizer",icon:"../../ae_TextureResizer/icon_textureresizer_24.png"},{icon:"../../Plugins/ae_MoleculeImporter/images/icon_moleculeimporter_24.png",file: "/Plugins/ae_MoleculeImporter/MoleculeImporter.rb",name: "MDL Molfile importieren [v3000, v2000] (*.mol)",description:"Importiert chemische Molekülmodelle aus dem MDL Molfile-Format.",category:"Plugins > Molekülimporter",id:72656,track:3, core:1.25204013377926}];
    return slice(rank(find(search_string)));
  };

  // Executes the UI::Command of a result.
  self.execute = function(identifier) {
    AE.Bridge.callRuby("execute", identifier);
  };

  // Private methods.

  // Searches the index data for matches to the search string.
  var find = function(search_string) {
    var result_array = [];
    var search_words = search_string.split(/\s/);
    // Loop over all entries in the index.
    for (var i=0; i < DATA.length; i++) {
      var entry = DATA[i];
      var score = 0;
      for (var j=0; j < search_words.length; j++) {
        var search_word = search_words[j];
        if (search_word == "") { continue };
        // We let single characters only match as the beginning of words.
        if (search_word.length == 1 && entry.name) {
          var regexp = new RegExp("^" + search_word);
          score += (entry.name.match(regexp) || []).length;
        } else {
          if (entry.name) score += 2 * (1 - rlevenshtein(search_word, entry.name)) * Math.pow(longest_common_substr_length(search_word, entry.name),2) + exact_matches(search_word, entry.name);
          if (entry.description) score += 2 * exact_matches(search_word, entry.description);
          if (entry.keywords) score += exact_matches(search_word, entry.keywords.join(" "));
          if (entry.file) score += exact_matches(search_word, entry.file);
        };
      };
      // Don't continue if no match has been found.
      if (score <= 0.5) { continue };
      // Save score and add the entry to results.
      entry.score = score;
      result_array.push(entry);
    };
    return result_array;
  };

  /* Sort the results by score. */
  var rank = function(result_array) {
    result_array.sort(function(a,b) {
      var A = parseFloat(a.score);
      var B = parseFloat(b.score);
      if (A < B) {return 1}
      else if (A > B) {return -1}
      else {return 0}
    })
    return result_array;
  };

  /* Reduces the results to a maximum amount (from option). */
  var slice = function(result_array) {
    return result_array.slice(0, Options.max_length||10);
  };

  /* Find the number of exact matches. */
  var exact_matches = function(search_word, string) {
    var regexp = new RegExp(search_word, "i");
    return (string.match(regexp) || []).length;
  };

  /* Levenshtein algorithm. */
  var levenshtein = function(str1, str2) {
    var m = str1.length,
      n = str2.length,
      d = [],
      i, j;
    if (!m) return n;
    if (!n) return m;
    for (i = 0; i <= m; i++) d[i] = [i];
    for (j = 0; j <= n; j++) d[0][j] = j;
    for (j = 1; j <= n; j++) {
      for (i = 1; i <= m; i++) {
        if (str1[i-1] == str2[j-1]) d[i][j] = d[i - 1][j - 1];
        else d[i][j] = Math.min(d[i-1][j], d[i][j-1], d[i-1][j-1]) + 1;
      }
    }
    return d[m][n];
  };

  /* Relative Levenshtein algorithm. */
  var rlevenshtein = function(str1, str2) {
    return (levenshtein(str1, str2) - Math.abs(str1.length - str2.length)) / Math.max(str1.length, str2.length);
  };

  /* Returns an array of pairs of neighbouring characters. */
  var get_bigrams = function(string) {
    var s = string.toLowerCase();
    var v = new Array(s.length-1);
    for (i = 0; i< v.length; i++) { v[i] = s.slice(i, i+2); }
    return v;
  };

  /* Perform bigram comparison between two strings and return a percentage match. */
  var string_similarity = function(str1, str2) {
    var pairs1 = get_bigrams(str1);
    var pairs2 = get_bigrams(str2);
    var union = pairs1.length + pairs2.length;
    var hit_count = 0;
    for (x in pairs1) {
      for (y in pairs2) {
        if (pairs1[x] == pairs2[y]) {
          hit_count++;
        }
      }
    }
    return ((2.0 * hit_count) / union);
  };

  /* Find the length of the longest sequence of characters that is identical in two strings. */
  var longest_common_substr_length = function(s, t) {
    var matchfound = 0;
    var l = s.length;
    for (var i=0; i<s.length; i++) {
      var os = 0;
      for (j=0; j<t.length; j++) {
        var re = new RegExp("(?:.{" + os + "})(.{" + l + "})", "i");
        var temp = re.test(s);
        re = new RegExp("(" + RegExp.$1 + ")", "i");
        if (re.test(t)) {
          matchfound = 1;
          result = RegExp.$1.length;
          break;
        }
        os += 1;
      }
      if (matchfound==1) {return result; break;}
      l -= 1;
    }
    return 0;
  };

  return self;
}(LaunchUp.Index || {}); // end module Index



/* module History:
 * This keeps a list of recently executed commands.
 */
var History = LaunchUp.History = function(self) {

  // Private variables.
  var DATA = [];
  var ELEMENT = null;
  var LIST = null;
  var MAX_LENGTH = 20;
  var STYLE = "slim";

  // Public methods.

  self.initialize = function(element) {
    ELEMENT = element;
    var ul = ELEMENT.getElementsByTagName("ul");
    LIST = (ul) ? ul[0] : ELEMENT.appendChild(document.createElement("ul"));
    if (!Options.style_history) { Options.style_history = STYLE }
    else { STYLE = Options.style_history }
    AE.Style.addClass(LIST, Options.style_history);
    if (!Options.history_max_length) { Options.history_max_length = MAX_LENGTH }
    if (!Options.history_entries) { Options.history_entries = [] }
  };

  /* Set the style of the list items. */
  self.updateStyle = function() {
    if (Options.style_history === STYLE) { return; }
    AE.Style.removeClass(LIST, STYLE);
    AE.Style.addClass(LIST, Options.style_history);
    STYLE = Options.style_history;
    AE.Dialog.adjustSize();
  };

  self.load = function(array) {
    if (AE.debug) { AE.Bridge.puts("loading "+array.length+" entries to History") } // DEBUG
    // Clear the history (since we will add the entries again).
    Options.history_entries.length = 0;
    // Build list of recent commands.
    var l = Math.min(array.length, Options.history_max_length);
    if (array) {
      for (var i=l-1; i>=0; i--) {
        try { self.add(array[i]) }
        catch (e) { if (AE.debug) { AE.Bridge.puts("History.load: Entry "+array[i].id+" could not be added") } };
      }
    };
    self.show();
    AE.Dialog.adjustSize();
  };

  self.add = function(entry) {
    if (entry.no_history === true) { return; }
    // Check that the new entry is not yet included in data:
    for (var i=0; i<DATA.length; i++) {
      if (DATA[i].id === entry.id) { return; }
    };
    // Add it to data.
    DATA.unshift(entry);
    Options.history_entries.unshift(entry.id);
    AE.Bridge.updateOptions({history_entries: Options.history_entries});
    // Create the HTML.
    var div = document.createElement("div");
    var li = document.createElement("li");
    li.setAttribute("id", "entry_" + entry.id);
    li.setAttribute("title", entry.description||entry.name||"" );
    li.appendChild(div);
    li.entry = entry;
    li.onclick = function() {
      if (Options.local_index) {
        Index.execute(entry.id);
      } else {
        AE.Bridge.callRuby("execute", entry.id);
      }
    };
    // Icon for the command.
    if (typeof(entry.icon) !== "undefined" && entry.icon !== null && entry.icon !== "") {
      var img = document.createElement("img");
      img.setAttribute("src", entry.icon);
      div.appendChild(img);
    };
    // Name of the command.
    var span = document.createElement("span");
    span.setAttribute("class", "name");
    span.appendChild(
      document.createTextNode(entry.name||""));
    div.appendChild(span);
    // Category of the command.
    if (entry.category) {
      var span = document.createElement("span");
      span.setAttribute("class", "category");
      span.appendChild(
        document.createTextNode(" "+entry.category));
      div.appendChild(span);
    }
    // Description of the command.
    if (entry.description !== entry.name) {
      var span = document.createElement("span");
      span.setAttribute("class", "description");
      span.appendChild(
        document.createTextNode(" "+entry.description||""));
      div.appendChild(span);
    }
    // Attach the entry into the DOM.
    LIST.insertBefore(li, LIST.firstChild);
    // Remove older entries.
    if (DATA.length > Options.history_max_length) {
      DATA.pop();
      Options.history_entries.pop();
      AE.Bridge.updateOptions({history_entries: Options.history_entries});
      LIST.removeChild(LIST.lastChild);
    };
    self.show();
    AE.Dialog.adjustSize();
  };

  /* Make the history visible again. */
  self.show = function() {
    //if (ELEMENT && ELEMENT.style && Options.show_history === true) { ELEMENT.style.visibility = "visible"; }
    if (ELEMENT && Options.show_history == true) { AE.Style.show(ELEMENT) };
  };

  /* Toggle the history temporarily off to make space for the search results. */
  self.hide = function() {
    //if (ELEMENT && ELEMENT.style) { ELEMENT.style.visibility = "hidden"; }
    if (ELEMENT) { AE.Style.hide(ELEMENT) };
  };

  /* Turn the history on. */
  self.on = function() {
    if (ELEMENT) { AE.Style.show(ELEMENT) };
    Options.show_history = true;
    AE.Bridge.updateOptions({show_history: true});
    AE.Dialog.adjustSize();
};

  /* Turn the history off. */
  self.off = function() {
    if (ELEMENT) { AE.Style.hide(ELEMENT) }
    Options.show_history = false;
    AE.Bridge.updateOptions({show_history: false});
    AE.Dialog.adjustSize();
  };

  return self;
}(LaunchUp.History || {}); // end module History



return LaunchUp;
}(AE.LaunchUp || {}); // end module LaunchUp



// Catch errors in the WebDialog and send them to the Ruby Console
window.onerror = function(errorMsg, url, lineNumber){
  AE.Bridge.puts("JavaScript error:\n"+url+" (line "+lineNumber+"): "+errorMsg);
  return true;
}
