LaunchUp
=================

## A Quick Launcher for SketchUp

This Plugin adds a quick launcher to search and execute commands.
* You can search for native SketchUp functions as well as plugins
  and select them by mouse or keyboard.
* Click the history/clock button to toggle a list of recently used
  commands that you don't need to search anymore (this can be used
  as a dynamic toolbar).
* Search for *"LaunchUp – Options"* to change settings.

**Recommended:**  SketchUp 8 M2 or higher (it works in a limited way in lower versions)

### Public methods:

You can use these methods to query LaunchUp in Ruby code:

* _**`AE::LaunchUp.look_up(search_string=[String],length=[Fixnum])`**_  
  Queries the index for seach terms and returns an Array of hashes as results.
  You can specify the amount of results. The resulting hash contains keys like:
  `:name`, `:description`, `:icon`, `:category`, `:keywords`, `:proc`, `:validation_proc`, `:id`

* _**`AE::LaunchUp.execute(identifier)`**_  
  Execute a command from the index, specified by the `:id` obtained from `look_up`.
  It returns a boolean indicating success or failure (command not found or failed
  to execute).

Debugging:

* _**`AE::LaunchUp.debug=([Boolean])`**_  
  Enables/Disables debugging messages.

* _**`AE::LaunchUp.reset`**_  
  Resets the options to the plugin's original state.
