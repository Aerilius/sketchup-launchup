/*
Library summary:
module AE
  .$(pattern, scope)                 // Selector function
  class Scheduler(dt)                // Execute functions no more frequent than limit.
    .queue(function)                 // Adds a function to functions that will be executed one by one.
    .add(function)                   // Adds to functions that will all be executed at next time.
    .replace(function)               // Sets given function in place of previously scheduled functions.
  module Style
    .hasClass(element, className)
    .addClass(element, className)
    .removeClass(element, className)
    .show(element)
    .hide(element)
  module Bridge                     // Communication with Ruby
    .callRuby(name, data, callbackFunction) // Executes a Ruby action_callback. The Ruby action_callback receives a string with the message id attached as a comment (#42).
    .callbackJS(id, data)          // To be called from Ruby action_callback, with message id and optional argument.
    .puts(object)                  // Outputs to Ruby console, the same for console.log().
    .updateOptions(hash)
    .updateOptionsfromForm(form)
  module Dialog                    // Dialog-related functions
    .initialize
    .adjustSize(width, height)
    .close
    .addOnFocus(function)          // Adds event handler for onfocus (taking care of WebDialog issues)
    .addOnBlur(function)           // Adds event handler for onblur (taking care of WebDialog issues)
  module Form
    .fill(hash, form, autoupdate)  // Automatically fills forms with values.
    .read(form)                    // Reads values from form.
*/

/*
 * module AE
 */
var AE = (function(AE) {


// A public debug variable.
AE.debug = false;

// Platform
AE.PLATFORM = (navigator.appVersion.indexOf("Win")!=-1)? "WIN" : ((navigator.appVersion.indexOf("OS X")!=-1)? "OSX" : "other");



/* Selector function.
 *   Args:
 *     pattern: a string that contains  #id,  .class  or  element
 *     scope: an HTMLElement into which the search should be limited
 *   Returns:
 *     HTMLElement (if #id given) or Array of HTMLElements
 */
AE.$ = function(pattern, scope) {
  // If no scope is given, elements are searched within the whole document.
  if (!scope) { scope = document }
  //
  var results = [],
  // This supports several selectors (ie. comma-separated, no nesting).
      selectors = pattern.split(/\s*?,\s*?/);
  for (var s=0; s < selectors.length; s++) {
    var selector = selectors[s];
    // ID
    if (selector.charAt(0) === "#") {
      var e = scope.getElementById(selector.slice(1));
      if (selectors.length>1) {
        results.push(e);
      // Since ID should be used only once, this selection is unambiguous and we return the element directly.
      } else {
        return e;
      }
    // Class
    } else if (selector.charAt(0) === ".") {
      // Modern browsers
      if (document.getElementsByClassName) {
        results = results.concat( Array.prototype.slice.call(scope.getElementsByClassName(selector.slice(1))) );
      // Older browsers
      } else {
        var cs = scope.getElementsByTagName("*");
        if (cs.length === 0) { continue; }
        var regexp = new RegExp('\\b'+selector.slice(1)+'\\b', 'gi');
        for (var i=0; i < cs.length; i++) {
          if (cs[i].className.search(regexp) !== -1) { results.push(cs[i]) }
        }
      }
    // [property=value]
    } else if (selector.charAt(0) === "[" && selector.slice(-1) === "]") {
      var attribute = selector.match(/[^\[\]\=]+/)[0];
      var value = selector.match(/\=[^\]]+(?=\])/);
      if (value !== null) { value = value[0].slice(1) }
      var cs = scope.getElementsByTagName("*");
      if (cs.length === 0) { continue; }
      for (var i=0; i < cs.length; i++) {
        var val = cs[i].getAttribute(attribute);
        if (val !== null && ((value !== null) ? (val === value) : true)) { results.push(cs[i]) }
      }
    // TagName
    } else {
      var cs = scope.getElementsByTagName(selector);
      for (var i=0; i < cs.length; i++) {
        results.push(cs[i]);
      }
    }
  }
  return results;
};



/* class Scheduler:
 * This class (to be instanced) makes sure given functions are not called more
 * frequently than a certain time limit. Note that the first function is run immediately and synchronously.
 * .queue(function)
 *     Adds a new function. All collected functions will be executed one by one with time interval inbetween.
 * .add(function)
 *     Adds a new function to a group of functions. All collected funcitons will be executed at once.
 * .replace(function)
 *     Adds a new function to be executed instead of the last function. This pattern
 *     allows to update actions, ie. with more up-to-date data or redrawing something etc.
 */
AE.Scheduler = function(dt) {
  var scheduled = []; // Array of scheduled functions.
  var t = 0; // Tracks the time of the last function call.
  dt = (dt) ? Number(dt) : 250; // Minimum time interval in milliseconds between subsequent function calls.
  this.queue = function(fn) {
    scheduled.push(fn);
    check();
  };
  this.add = function(fn) {
    last = scheduled[scheduled.length-1];
    if (scheduled.length === 0 || last && typeof last === "function") { scheduled.push([fn]); }
    else { last.push(fn); } // Add to Array.
    check();
  };
  this.replace = function(fn) {
    if (scheduled.length > 0) { scheduled.pop(); }
    scheduled.push(fn);
    check();
  };
  var run = function() {
    var toRun = scheduled.shift();
    // Function
    if (typeof toRun === "function") { toRun(); }
    // Array of functions
    else if (Object.prototype.toString.call(toRun) === '[object Array]') {
      for (var i=0; i<toRun.length; i++) {
        toRun[i]();
      }
    }
  };
  var check = function() {
    var c = Number(new Date().getTime());
    // Last function call is long enough ago (or first time), execute given function immediately.
    if (c > t && scheduled.length > 0) {
      run();
      // Set timer for next possible function call.
      t = c + dt;
      window.setTimeout(check, dt);
    }
  };
};



/* module Translate (dummy):
 * In case no translation has been loaded.
 */
if (!AE.Translate) { AE.Translate = { get: function(s) {return s} } }



/* module Style:
 * Custom methods to access/manipulate style-related things.
 */
AE.Style = (function(self) {

  /* Check if an element has a specific class. */
  self.hasClass = function(element, className) {
    if (!element || !element.className || !className) { return false; }
    var r = new RegExp("(^|\\b)" + className + "(\\b|$)");
    return  r.test(element.className);
  };

  /* Add a class to an element. */
  self.addClass = function (element, className) {
    if (!element || !className) { return; }
    if (!element.className) { element.className = "" }
    if (!self.hasClass(element, className)) {
      element.className += (element.className !== '' ? ' ' : '') + className;
    }
  };

  /* Remove a class from an element. */
  self.removeClass = function(element, className) {
    if (!element || !element.className || !className) { return false; }
    var r = new RegExp("(^\\s*|\\s*\\b)" + className + "(\\b|$)", "gi");
    element.className = element.className.replace(r, "");
  };

  /* Show an element. (using display) */
  self.show = function(element) {
    if (!element) { return; }
    if (element.style.display === "none") { element.style.display = element.original_display || "block" }
  };

  /* Hide an element. (using display) */
  self.hide = function(element) {
    if (!element || element.style.display == "none") { return; }
    // Remember the original display property because it could be block, inline-block, inline etc.
    element.original_display = element.style.display;
    element.style.display = "none";
  };

  return self;
}(AE.Style || {})); // end module Style



/* module Bridge:
 * Methods to interact with SketchUp/Ruby.
 */
AE.Bridge = (function(self) {

  var messageID = 0;
  // Private object to hold callback functions.
  var callbacks = {};
  // SketchUp/OSX/Safari skips skp urls if they happen in a too short time interval.
  // We pass all skp urls through a scheduler that makes sure that between each
  // url request is a minimum time span.
  var scheduler = new AE.Scheduler(1);

  /* Function to call a SketchUp Ruby action_callback. */
  self.callRuby = function(name, data, callbackFunction) {
    // if (!/SketchUp/i.test(navigator.userAgent)) { return console.log(JSON.stringify([name, data, callbackFunction])) } // DEBUG: Only SU8Win has "SketchUp" in the user agent!
    data = rubify(data);
    // We assign an id to this message so we can identify a callback (if there is one).
    if (callbackFunction) { callbacks[messageID] = callbackFunction }
    // Trick: Since we Ruby-hash-encode the data we can pass an ID as a comment
    // at the end. This does not have an impact when using eval, to_i, to_f on
    // the Ruby side. In Ruby we can optionally extract the id and call:
    // AE.Bridge.callbackJS(id, data)
    var url = "skp:" + name + "@" + encodeURIComponent(data) + "#" + messageID;
    scheduler.queue(function(){ window.location.href = url; });
    // Increase the id for the next message.
    messageID++;
    // Return the id of this message.
    return messageID - 1
  };

  /* Call a SketchUp Ruby action_callback. */
  self.callbackJS = function(id, data) {
    if (AE.debug) { AE.Bridge.puts("Dialog.callbackJS called with id #"+id); } // DEBUG
    if (callbacks[id]) {
      try { callbacks[id](data) }
      catch (e) { if (AE.debug) { AE.Bridge.puts("AE.Dialog.callbackJS: Error when executing callback #"+id); } }
      delete callbacks[id];
    } else {
      if (AE.debug) { AE.Bridge.puts("AE.Dialog.callbackJS: No callback found for #"+id); }
    }
  };

  /* For debugging. */
  self.puts = function(text) {
    self.callRuby("puts",  text);
  };

  /* For debugging. If no browser console defined, link to the Ruby Console. */
  window.console = window.console || {
    log: function(text) { self.puts(text) }
  };

  /* A Method to produce a JSON string from a JSON object */
  var stringify = function(object) {
    //if (JSON) return JSON.stringify(object); // only IE8+
    if (Object.prototype.toString.call(object) === "[object Array]") {
      var a = [];
      for (var i=0; i < object.length; i++) {
        var v = stringify(object[i]);
        if (!!v) { a.push(v) }
      }
      return '[' + a.join(', ') + ']';
    } else if (typeof object === "object") {
      var o = [];
      for (var e in object) {
        // if (object.hasOwnProperty(e)) { // Out of memory?!
        var k = stringify(e);
        var v = stringify(object[e]);
        if (!!k && !!v) { o.push(k + ": " + v) }
        // }
      }
      return '{' + o.join(', ') + '}';
    } else if (typeof object === "string") {
      return '"' + object.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\'/g, "\\'").replace(/\#/g, "\\#") + '"';
    } else if (typeof object === "number" || typeof object === "null" || typeof object === "boolean") {
      return String(object);
    } // else: undefined
  };

  /* A Method to produce a Ruby object string from a JSON object */
  var rubify = function(object) {
    var rubyString = '';
    // null → nil
    if (typeof object === 'null' || typeof object === 'undefined') {
      rubyString = 'nil';
    // Array → Array
    } else if (Object.prototype.toString.call(object) === '[object Array]') {
      var a = [];
      for (var i=0; i < object.length; i++) {
        var v = rubify(object[i]);
        if (!!v) { a.push(v) }
      }
      rubyString = '[' + a.join(', ') + ']';
    // Object → Hash
    } else if (Object.prototype.toString.call(object) === '[object Object]') {
      var o = [];
      for (var e in object) {
        // if (Object.prototype.hasOwnProperty.call(object, e)) { // Out of memory?!
        var k;
        // Convert String keys into Symbol.
        if (typeof e === 'string') {
          k = ':' + ( /^[a-zA-Z\_]+[\!\?\=]?$/.test(e) ? e : rubify(e));
        } else { k = rubify(e) }
        var v = rubify(object[e]);
        if (!!k && !!v) { o.push(k + ' => ' + v) }
        // }
      }
      rubyString = '{' + o.join(', ') + '}';
    // String → String
    } else if (typeof object === 'string') {
      rubyString = '"' + object.replace(/\\/g, '\\\\').replace(/\"/g, '\\\"').replace(/\'/g, "\\'").replace(/\#/g, '\\#') + '"';
    // Number → Numeric
    } else if (typeof object === 'number' || typeof object === 'boolean') {
      if (isNaN(object)) { rubyString = '0.0/0.0'; }
      else if (!isFinite(object)) { rubyString = (object > 0) ? '1.0/0.0' : '-1.0/0.0'; }
      else { rubyString = String(object); }
    } // else: undefined
    return rubyString;
  };

  /* A method to send key/values in a Ruby hash. Needs corresponding
   * implementation on the Ruby side.
   */
  self.updateOptions = function(hash) {
    self.callRuby('update_options', hash);
  };

  /* A method to retrieve options from form elements and send them to Ruby. */
  self.updateOptionsfromForm = function(form) {
    self.updateOptions(AE.Form.read(form));
  };

  return self;
}(AE.Bridge || {})); // end module Bridge



/* module Dialog:
 * Methods to interact with the Webdialog (especially from Ruby).
 */
AE.Dialog = (function(self) {
  // Create a scheduler object to prevent too frequent requests. This will drop
  // all requests except of the latest within 250ms.
  var initialized = false;
  var scheduler = new AE.Scheduler(250); // If there are again problems in Safari, 500 could be better.

  // Private methods.

  var windowWidth = function() {
    return window.innerWidth || document.documentElement.clientWidth;
  };

  var windowHeight = function() {
    return window.innerHeight || document.documentElement.clientHeight;
  };

  var documentWidth = function() {
    return document.body.offsetWidth;
  };

  var documentHeight = function() {
    h = document.documentElement.offsetHeight
    if (h == windowHeight() || h == 0) { h = document.body.offsetHeight };
    return h;
  };

  // Public methods.

  /* Measure the visible inner height of the window.
   * Then return it to ruby, substract it from outer height to get the height of the window titlebar.
   * This is important so that we have precise control over the window dimensions
   */
  self.initialize = function() {
    var w = windowWidth();
    var h = windowHeight();
    var sw = screen.width;
    var sh = screen.height;
    initialized = true;
    AE.Bridge.callRuby("window_dimensions", [w, h, sw, sh]);
  };

  /* Method to adjust the size of the dialog to its content or a specified size. */
  self.adjustSize = function(w, h) {
    // Measure the document's width and height.
    //if (AE.debug) { AE.Bridge.puts(["width of document", document.body.offsetWidth, document.body.clientWidth, document.body.scrollWidth, document.documentElement.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth]); } // DEBUG
    //if (AE.debug) { AE.Bridge.puts(["height of document", document.body.offsetHeight, document.body.clientHeight, document.body.scrollHeight, document.documentElement.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight]); } // DEBUG
    w = documentWidth();
    h = documentHeight();
    // We send also the dialog's position to Ruby because we need to override the dialog position on OSX.
    var l = window.screenX || window.screenLeft;
    var t = window.screenY || window.screenTop;
    if (AE.debug) { AE.Bridge.puts("AE.Dialog.adjustSize("+w+", "+h+", "+l+", "+t+")"); } // DEBUG
    scheduler.replace(function(){
      AE.Bridge.callRuby("adjust_size", [w, h, l, t]);
    });
  };

  /* Close the dialog */
  self.close = function() {
    AE.Bridge.callRuby("close");
    window.close();
  };

  /* Wrapper around window.onfocus or window.onblur.
   * Problem:
   * 1.) Internet Explorer has a different implementation of the window.onfocus/onblur
   *     events and triggers onblur when an element inside the window takes focus.
   *     Internet Explorer uses onfocusin/onfocusout instead.
   * 2.) When SketchUp's UI::WebDialg is resized, it gets focus and triggers a
   *     cascade of events (focus, blur, focus, blur ...). This utility function
   *     filters out unnecessary events.
   */
  var hasFocus = true;
  var focussing = false;
  var blurring = false;
  var addEvent = function(eventType, fn) {
    if (document.addEventListener) {
      document.addEventListener(eventType, fn, false);
      return true;
    } else if (document.attachEvent) {
      return document.attachEvent("on"+eventType, fn);
    }
  };
  self.addOnFocus = function(fn) {
    // In Internet Explorer, window.focus is bugged and does not trigger when the
    // window is focussed by clicking/focussing an element inside it.
    var eventType = ("onfocusin" in document.documentElement) ? "focusin" : "focus";
    // This function triggers only when the document didn't have focus for 100 ms.
    var filterFn = function(event) {
      if (!event) { event = window.event }
      if (!hasFocus && !blurring && !focussing) {
        hasFocus = true;
        focussing = true;
        window.setTimeout(function(){ focussing = false }, 100);
        fn(event);
      } else { hasFocus = false }
    };
    // Attach it to the document
    addEvent(eventType, filterFn);
  };
  self.addOnBlur = function(fn) {
    // In Internet Explorer, window.blur is bugged and triggers also when an
    // element inside the window takes focus instead.
    var eventType = ("onfocusout" in document.documentElement) ? "focusout" : "blur";
    // This function triggers only when the document has been focussed for 100 ms.
    var filterFn = function(event) {
      if (!event) { event = window.event }
      // Internet Explorer triggers onfocusout, if an element looses focus by
      // focussing another element. By using a timeout of 0, we allow the other
      // element to trigger first, and with an onfocusin.
      window.setTimeout(function(){
        if (hasFocus && !blurring && !focussing) {
          blurring = true;
          window.setTimeout(function(){
            blurring = false;
            hasFocus = false;
          }, 100);
          fn(event);
        }
      }, 0);
    };
    // Attach it to the document
    addEvent(eventType, filterFn);
  };

  return self;
}(AE.Dialog || {})); // end module Dialog



/* module Form:
 * Methods to interact with the Webdialog or Ruby.
 */
AE.Form = (function(self) {

  /* Load default data into form elements.
   * Identifies input elements when their name matches the default's name.
   */
  self.fill = function(hash, form, autoupdate) {
    if (!form) { form = document.getElementsByTagName("form")[0] || document.body }
    var inputs = AE.$("input", form).concat(AE.$("select", form));
    for (var i=0; i < inputs.length; i++) {
      var input = inputs[i];
      // Since we don't use hyphens in Ruby Symbols, we normalize input names as well.
      var name = input.name.replace(/\-/,"_");
      // If options contain a key that matches the input's name; radios only when the value matches.
      if ((name in hash) && (input.type === "radio" && hash[name] === input.value || input.type !== "radio")) {
        // Checkbox
        if (input.type === "checkbox") {
          input.checked = hash[name];
        }
        // Radio
        else if (input.type === "radio") {
          input.checked = true;
        }
        // Multiple select
        else if (input.type === "select-multiple" && hash[name] !== null && hash[name].constructor() === Array) {
          for (var j=0; j < input.length; j++) {
            for (var k=0; k < hash[name].length; k++) {
              if (input[j].value === hash[name][k]) { input[j].selected = true }
            }
          }
        }
        // Text or select
        else {
          input.value = hash[name];
        }
      }
      // Optionally add an event handler to update the key/value in Ruby.
      if (autoupdate === true) {
        var fn = function(name,input){
          return function() {
            var hash = {};
            hash[name] = input.value;
            AE.Bridge.callRuby('update_options', hash);
          };
        }(name,input);
        if (input.addEventListener) {
          input.addEventListener("change", fn, false);
        } else if (input.attachEvent) {
          input.attachEvent("onchange", fn);
        }
      }
    }
  };

  /* Read user input from input elements.
   * Identifies key names from the name attribute of input elements.
   */
  self.read = function(form) {
    if (!form) { form = document.getElementsByTagName("form")[0] || document.body }
    var inputs = AE.$("input", form).concat(AE.$("select", form));
    var hash = {};
    for (var i=0; i < inputs.length; i++) {
      var input = inputs[i];
      // Continue only if the input is enabled and has a name.
      if (input.disabled || !input.name || input.name === "") { continue; }
      var key = input.name;
      // Checkbox: Boolean true/false
      if (input.type === "checkbox") {
        hash[key] = input.checked;
      }
      // Radio checked: value as Symbol
      else if (input.type === "radio" && input.checked) {
        hash[key] = input.value;
      }
      else if (input.type === "radio" && !input.checked) {}
      // Text that is number: Numeric
      else if (!isNaN(input.value) && (input.type === "text" && /\b(num|number|numeric|fixnum|integer|int|float)\b/i.test(input.className) || input.type === "number")) {
        // [optional] Use html5 step attribute or classNames to distinguish between Integer and Float input.
        if (input.step && (input.step%1) === 0 || input.className && /\b(fixnum|integer|int)\b/i.test(input.className)) {
          hash[key] = parseInt(input.value);
        } else { // if (input.step && (input.step%1) !== 0 || input.className && /\bfloat\b/i.test(input.className)) {
          hash[key] = parseFloat(input.value);
        }
      }
      // Select multiple: Array of Strings
      else if (input.type === "select-multiple") {
        var s = [];
        for (var j=0; j < input.length; j++) {
          if (input[j].selected) { s.push(input[j].value) }
        }
        hash[key] = s;
      }
      // Text or select: String
      else {
        hash[key] = String(input.value);
      }
    }
    return hash;
  };

  return self;
}(AE.Form || {})); // end module Dialog



return AE;
}(AE || {})); // end module AE
