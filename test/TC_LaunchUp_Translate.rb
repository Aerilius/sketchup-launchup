require 'sketchup.rb'
require 'test/unit'



class TC_LaunchUp_Translate < Test::Unit::TestCase



def setup
  # Create a mock for the locale.
  @original_locale = Sketchup.get_locale
  def Sketchup.set_locale(string); @locale = string; end
  def Sketchup.get_locale; return @locale; end
  @dir = File.join(File.dirname(__FILE__), "TC_LaunchUp_Translate")
end



def teardown
  Sketchup.set_locale(@original_locale)
end



def test_initialize
  # It should accept optionally a toolname as prefix for translation files.
  assert_nothing_raised("Translate.initialize: first argument should accept a string or nil.") { AE::LaunchUp::Translate.new("test") }
  assert_raise(ArgumentError, "Translate.initialize: first argument should only accept a string.") { AE::LaunchUp::Translate.new(42) }
  assert_raise(ArgumentError, "Translate.initialize: first argument should only accept a string.") { AE::LaunchUp::Translate.new(3.14) }
  assert_raise(ArgumentError, "Translate.initialize: first argument should only accept a string.") { AE::LaunchUp::Translate.new(Object.new) }
  # The second must be a string as a directory where to look for translation files.
  assert_nothing_raised("Translate.initialize: second argument should accept a string.") { AE::LaunchUp::Translate.new("test", @dir) }
  assert_raise(ArgumentError, "Translate.initialize: second argument should only accept a string.") { AE::LaunchUp::Translate.new("test", 42) }
  assert_raise(ArgumentError, "Translate.initialize: second argument should only accept a string.") { AE::LaunchUp::Translate.new("test", 3.14) }
  assert_raise(ArgumentError, "Translate.initialize: second argument should only accept a string.") { AE::LaunchUp::Translate.new("test", Object.new) }
end



def test_parse_strings
  # It should optionally accept a toolname as prefix of translation files, a locale and a directory to look for translation files.
  Sketchup.set_locale("no")
  translate = AE::LaunchUp::Translate.new(nil, @dir)
  assert(translate.get("parsed no") == "true", "It should optionally accept a toolname as prefix of translation files.")

  # It should prefer a language/country locale, but fallback to a language locale.
  Sketchup.set_locale("xy") # No such file available.
  translate = AE::LaunchUp::Translate.new("test", @dir)
  assert(translate.get("locale") == "en", "It should choose the locale 'en' as fallback if locale does not match at all.")
  # TODO: get detected locale or parsed language file and compare. Maybe add to language file a special string that allows to identify it.
  # This should fallback to English.
  Sketchup.set_locale("fr")
  translate = AE::LaunchUp::Translate.new("test", @dir)
  assert(translate.get("locale") == "fr", "It should choose the locale if it matches exactly.")

  Sketchup.set_locale("pt-BR")
  translate = AE::LaunchUp::Translate.new("test", @dir)
  assert(translate.get("locale") == "pt-BR", "It should choose a locale if both language and country match.")

  Sketchup.set_locale("pt-PT") # No such file available but "pt-BR".
  translate = AE::LaunchUp::Translate.new("test", @dir)
  assert(translate.get("locale") == "pt-BR", "It should choose a locale with same language if the language matches but not country.")

  Sketchup.set_locale("de-AT") # No such file available but "de".
  translate = AE::LaunchUp::Translate.new("test", @dir)
  assert(translate.get("locale") == "de", "It should choose a locale with same language if the language matches but not country.")

  Sketchup.set_locale("st") # No such file available.
  translate = AE::LaunchUp::Translate.new("test", @dir)
  assert(translate.get("locale") == "en", "It should choose the locale 'en' as fallback if locale does not match at all.")

  # It should parse .strings, .lingvo and .rb files.
  # For each of these imaginary language codes, only a single format is available.
  Sketchup.set_locale("st")
  translate = AE::LaunchUp::Translate.new("test2", @dir)
  assert(translate.get("parsed st") == "true", "It should choose the available translation format.")

  Sketchup.set_locale("li")
  translate = AE::LaunchUp::Translate.new("test2", @dir)
  assert(translate.get("parsed li") == "true", "It should choose the available translation format.")

  Sketchup.set_locale("rb")
  translate = AE::LaunchUp::Translate.new("test2", @dir)
  assert(translate.get("parsed rb") == "true", "It should choose the available translation format.")

  # for .strings:
  Sketchup.set_locale("st")
  translate = AE::LaunchUp::Translate.new("test3", @dir)
  #  It should tolerate inline comments /* */ over several lines and end-of-line comments //.
  assert(translate.get("single line comment") != "false", "It should tolerate single line comments with //.")
  assert(translate.get("multiple line comment") != "false", "It should tolerate multiple line comments with /* */.")
  assert(translate.get("single line end comment") != "false", "It should not parse after single line comment starts in the same line.")
  assert(translate.get("before multiple line comment") != "false", "It should parse before multiple line comment starts in the same line.")
  assert(translate.get("single 'quotes'") == "true", "It should parse single quotes.")
  assert(translate.get("double \"quotes\"") == "true", "It should parse double quotes.")
  assert(translate.get("entity reference for &quote;quotes&quote;") == "true", "It should parse entity references for double quotes.")
  assert(translate.get("escape \\") == "true", "It should parse escape characters.")
  assert(translate.get("equal with spaces") == "true", "It tolerate equal sign with whitespace.")
  assert(translate.get("semicolon with spaces") == "true", "It should tolerate whitespace before semicolon.")
  assert(translate.get("semicolon missing") != "false", "It does not need to parse if semicolon missing at the end.")
  assert(translate.get("after semicolon missing") != "false", "It does not need to parse after semicolon missing.")
  # TODO:
  assert(translate.get("before single line comment") == "true", "It should parse before single line comment starts in the same line.") # TODO
  assert(translate.get("forward slash //") == "true", "It should parse double forward slashes.") # TODO
  assert(translate.get("forward slash asterisk /* */") == "true", "It should parse slash asterisk combination.") # TODO
  # TODO: What about line breaks?
  # It should merge the parsed key/value pairs into @strings (overriding existing keys).
  # It should return false if no strings were parsed or an error occured, otherwise true.
end



def test_get
  Sketchup.set_locale("st")
  translate = AE::LaunchUp::Translate.new("test4", @dir)
  # It should be aliased as [].
  assert(translate.method(:[]) == translate.method(:get), "It should be aliased as [].")
  # It should accept a string or array of strings and optionally any amount of strings. It should tolerate nil.
  assert_nothing_raised("Translate.get: argument should accept a string.") { translate.get("something") }
  assert_nothing_raised("Translate.get: argument should tolerate nil.") { translate.get(nil) }
  assert_nothing_raised("Translate.get: argument should accept an array of strings.") { translate.get(["something", "something more"]) }
  assert_raise(ArgumentError, "Translate.get: argument should only accept a string or array.") { translate.get(42) }
  assert_raise(ArgumentError, "Translate.get: argument should only accept a string or array.") { translate.get(3.14) }
  assert_raise(ArgumentError, "Translate.get: argument should only accept a string or array.") { translate.get(Object.new) }
  assert_raise(ArgumentError, "Translate.get: argument should only accept a string or array of strings.") { translate.get(["something", 42]) }
  assert_raise(ArgumentError, "Translate.get: argument should only accept a string or array of strings.") { translate.get(["something", 3.14]) }
  assert_raise(ArgumentError, "Translate.get: argument should only accept a string or array of strings.") { translate.get(["something", Object.new]) }
  # If a string is given, it should return the translated string or the original string.
  assert(translate.get("not found") == "not found", "It should return the original string if no translation is found.")
  assert(translate.get("something") == "true", "It should return the translated string if a translation is found.")
  # If an array is given, it should call itself on each string in the array and return the array.
  assert(translate.get(["not found"]) == ["not found"], "It should return the original array if no translations are found.")
  assert(translate.get(["something"]) == ["true"], "It should return an array of translated strings if translations are found.")
  # If optional additional strings are given, these should be inserted at every %0, %1 etc.
  assert(translate.get("includes %0, %1 and %2", "a") == "includes a, %1 and %2", "It should insert additional strings if percent numbers are given.")
  assert(translate.get("includes %0, %1 and %2", "a", "b", "c") == "includes a, b and c", "It should insert additional strings if percent numbers are given.")
  assert(translate.get("different order: %2, %1 and %0", "a", "b", "c") == "different order: c, b and a", "It should insert additional strings if percent numbers are given.")
end



def test_webdialog
  # It should translate all text nodes and all title and value attributes of all HTMLElements.
  # It should provide a method AE.Translate.get to translate a string.
  # This method should remove whitespace at the beginning and end of the string.
end



end # class TC_LaunchUp_Translate
