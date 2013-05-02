/* module LaunchUp:
 * Methods for the SketchUp plugin LaunchUp.
 */
AE.LaunchUpOptions = function(LaunchUpOptions) {



var $ = AE.$;



/* Object to hold options.
 */
var Options = LaunchUpOptions.Options = {
};



LaunchUpOptions.initialize = function(opt) {
  if (!opt) { opt = {} }
  for (var i in opt) { Options[i] = opt[i] }
  if (Options.debug) { AE.debug = Options.debug }

  /* Load defaults.
   * Identifies input elements when their name matches the default option's name.
   */
  AE.Form.fill(Options, null, true);

  // Set color selection to toggle input field for custom color.
  $("#color").onchange = function () {
    if ($("#color_custom").selected) {
      AE.Style.show($("#color_custom_inputs"));
    } else {
      AE.Style.hide($("#color_custom_inputs"));
    };
    AE.Dialog.adjustSize();
  };
  $("#color").onchange();

  // OK button.
  $("#ok_button").onclick = function() {
    // Now all inputs have sent changes back to Ruby so we don't need to send all
    // input back.
    // AE.Bridge.updateOptions(AE.Form.read());
    AE.Dialog.close();
  };

  // Prevent page reloading on buttons in form element.
  $("form")[0].onsubmit = function() { return false };

  // Adjust the size (height) when the dialog has been manually resized.
  // Internet Explorer it requires a little delay to complete resizing because it triggers
  // onresize twice (for height & width). Otherwise we would use incorrect
  // dimensions and the dialog flickers.
  window.onresize = function(){ window.setTimeout(AE.Dialog.adjustSize, 0) };

  // Initialize the Dialog module.
  AE.Dialog.initialize();
};



return LaunchUpOptions;
}(AE.LaunchUpOptions || {}); // end module LaunchUp
