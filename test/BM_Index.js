// Patch to LaunchUp.js for creation of the search benchmakr database.

AE.LaunchUp.ComboBox = (function(self){
  // Private variables.
  var INPUT = null;
  var LIST = null;
  var DEFAULT_OVERLAY = null;
  var INPUT_TEXT = ''; // This variable keeps a copy of the original text that has been typed into the input field.
  var MIN_LENGTH = 0; // Minimum length of input before search starts.
  var SELECTED = -1; // Index of selected entry in dropdown list. (This is not a DATA id.)
  var SCHEDULER = new AE.Scheduler(500); // Allows to reduce too frequent search requests to 1 per 500ms.

  var old_initialize = self.initialize;
  self.initialize = function(input, list) {
    old_initialize(input, list);
    INPUT = input;
    LIST = list;

    // This sends ratings back to ruby as soon as you do a new search.
    var INPUTvalue = '';
    INPUT.onkeyup = function(event) {
      // For benchmarking the quality of the search algorithm(s).
      // Before we do a new search, we check if there are ratings of a previous search.
      //if (time_last_search && Number(new Date()) - time_last_search < 3) {
        var inputs = AE.$('input');
        // Continue only if there are search results.
        if (INPUT.value.length>0 && inputs.length >= 2) {
          var ratings = {};
          for (var i=0; i<inputs.length; i++) {
            var input = inputs[i];
            if (input.type === 'text' && input.id && input !== INPUT && input.value.length>0) {
              ratings[parseInt(input.id)] = parseInt(input.value);
            }
          }
          AE.Bridge.callRuby('optimization_database', [INPUTvalue, ratings]);
        }
      //}; time_last_search = Number(new Date());
      INPUTvalue = INPUT.value;

      // Original onkeyup:
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
      else if ( keycode == 13 && LIST.getElementsByTagName('li').length > 0 ) {
        if (SELECTED == -1) { select(0) };
        submit();
      }
      // other keys
      else {
        // To prevent complete searches at every key event, we use a scheduler to limit them to a minimum interval.
        SCHEDULER.replace(function() {
          SELECTED = -1;
          INPUT_TEXT = INPUT.value;
          if (INPUT_TEXT == '') {
            //emptyList(); // TODO
            AE.Style.show(DEFAULT_OVERLAY);
          } else if (INPUT_TEXT.replace(/^\s+|\s+$/g, '').length > MIN_LENGTH) {
            AE.Style.hide(DEFAULT_OVERLAY);
            AE.Bridge.callRuby('look_up', INPUT_TEXT, function(results){ rebuild(results) } );
          }
        });
      }
    }; // end function onkeyup
  };

  // This builds input elements into the list.
  // I could not easily insert the additional code, so this is a modified
  // copy of the original method:

  /* redefine: Build the suggestion list. */
  var rebuild = function(results) {
    if (!results) results = [];
    // Empty the results in the combo-list element.
    LIST.innerHTML = '';
    SELECTED = -1;
    // Generate an entry for each result.
    for (var i=0; i<results.length; i++) {
      // Container element(s)
      var entry = results[i];
      if (typeof(entry)==='undefined' || entry === null) { continue; }
      var div = document.createElement('div');
      var li = null;
      var li = document.createElement('li');
        li.setAttribute('id', 'entry_' + entry.id);
        li.setAttribute('title', entry.description||entry.name||'' );
        li.appendChild(div);
        li.entry = entry;
        // If the entry is enabled (or no such info known), its action can be executed.
        if (entry.enabled !== false) {
          li.onclick = function() {
            if (AE.debug) AE.Bridge.puts(Number(new Date())+' '+this.entry.id+' clicked'); // DEBUG
            submit(this.entry);
          }
        // Otherwise show it grayed.
        } else {
          li.setAttribute('class', 'grayed');
          li.onclick = function() {
            History.add(this.entry);
          }
        };
      // <INSERTION
      // For benchmarking the quality of the search algorithm(s).
      // Create a text input where I can insert a rating (0-10) for each result.
      li.onclick = null;
      var input = document.createElement('input');
      input.setAttribute('id', entry.id);
      input.style.maxWidth = '3em';
      input.style.float = 'right';
      div.appendChild(input);
      // INSERTION>
      // Icon for the command.
      if (typeof(entry.icon) !== 'undefined' && entry.icon !== null && entry.icon !== '') {
        var img = document.createElement('img');
        img.setAttribute('src', entry.icon);
        div.appendChild(img);
      };
      if (AE.debug) { // DEBUG
        // Score (for debugging correct order).
        div.appendChild(
          document.createElement('span').appendChild(
            document.createTextNode( Math.round(100*entry.score)/100 )));
        // ID (for debugging).
        div.appendChild(
          document.createElement('span').appendChild(
            document.createTextNode( '('+entry.id+')' )));
      };
      // Name of the command.
      var span = document.createElement('span');
      span.setAttribute('class', 'name');
      span.appendChild(
        document.createTextNode(entry.name||''));
      div.appendChild(span);
      // Category of the command.
      if (entry.category) {
        var span = document.createElement('span');
        span.setAttribute('class', 'category');
        span.appendChild(
          document.createTextNode(' '+entry.category));
        div.appendChild(span);
      }
      // Description of the command.
      if (AE.debug && typeof entry.dbg_info !== 'undefined' && entry.dbg_info !== null) { entry.description = entry.dbg_info + ' ' + entry.description } // DEBUG
      if (entry.description !== entry.name) {
        var span = document.createElement('span');
        span.setAttribute('class', 'description');
        span.appendChild(
          document.createTextNode(' '+entry.description||''));
        div.appendChild(span);
      }
      // Attach the entry into the DOM.
      LIST.appendChild(li);
    }
    AE.Dialog.adjustSize();
  }; // end function rebuild

  return self;
})(AE.LaunchUp.ComboBox)
