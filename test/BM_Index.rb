=begin
This file allows to benchmark the search algorithm of LaunchUp by comparing the
order of results with a database of expected results. It can automatically run
hundreds of searches and was supposed to show how a modification/optimization of
the search algorithm impacts the quality/relevance of results.

Load it after LaunchUp, but before opening the LaunchUp dialog. It adds input
fields into the search results where you can rate the placement/order of results
from 0 to 10 (best).
Run AE::LaunchUp.run_benchmark to get a score (around 170–200) of the current
search algorithm (heigher number = better).
=end



module AE



module LaunchUp



BM_INDEX_ROOT = File.dirname(__FILE__) unless defined?(BM_INDEX_ROOT)

#require 'sketchup.rb'
load(File.join(File.dirname(BM_INDEX_ROOT), 'src', 'ae_LaunchUp', 'LaunchUp.rb'))

# Data for optimizing the search algorithm.
load(File.join(BM_INDEX_ROOT, 'BM_Index_database.rb'))



def self.save_optimization_database
  file = File.join(BM_INDEX_ROOT, "BM_Index_database.rb")
  File.open(file, "w"){|f|
    f.puts("# This file contains search strings with expected results rated from 0 (bad) to 10 (good).\nmodule AE\nmodule LaunchUp\n@optimization_database=")
    f.print(@optimization_database.inspect)
    f.puts("\nend\nend")
  }
  return true
rescue
  return false
end



def self.run_benchmark
  load(File.join(File.dirname(BM_INDEX_ROOT), 'src', 'ae_LaunchUp', 'Index.rb'))
  rating = 0
  t = Time.now.to_f
  @optimization_database.each{|search_word, hash|
    results = self.look_up(search_word, 10)
    results.each_with_index{|result, i|
      id = result[:id]
      next unless hash.include?(id) && hash[id].is_a?(Numeric)
      rating += (10-i) * hash[id]
    }
  }
  puts("Time: #{(Time.now.to_f - t)/(@optimization_database.length|1)}")
  rating /= @optimization_database.length.to_f
  return rating
end



unless file_loaded?(File.basename(__FILE__))

  class << self
    alias_method(:show_dialog_old, :show_dialog)
  end

end # end unless



  # Changes to the LaunchUp dialog that add input fields next to each search result.
  # Instead of executing an action, you can enter a rating of each result from 0 to 10.
  def self.show_dialog
    self.show_dialog_old
    @launchdlg.add_action_callback("initialize") {|dlg, param|
      TRANSLATE.webdialog(dlg)
      # Prevent that the dialog collapses:
      dlg.execute_script("AE.Dialog.addOnFocus = function(){}; AE.Dialog.addOnBlur = function(){};")
      # Inject code into the ComboBox:
      js_file = File.expand_path(File.join(BM_INDEX_ROOT, "BM_Index.js"))
      dlg.execute_script("
      var s = document.createElement('script');
      s.setAttribute('src','#{js_file}');
      /*s.onload = function(){
      };*/
      document.body.appendChild(s);
      ")
      UI.start_timer(1, false){dlg.execute_script("AE.LaunchUp.initialize(#{@options.get_json});")}
    }

    # Collect data for the benchmark database.
    @launchdlg.add_action_callback("optimization_database") { |dlg, param|
      search_word, hash = eval(param) rescue next
      next if hash.empty?
      search_word.downcase!
      @optimization_database ||= {}
      @optimization_database[search_word] ||= {}
      hash.each{|id, rating|
        id = id.to_s.to_i unless id.is_a?(Fixnum)
        @optimization_database[search_word][id] ||= rating
        old_rating = @optimization_database[search_word][id]
        @optimization_database[search_word][id] = (2*old_rating + rating) / 3.0
      }
      @optimization_database[search_word].merge!(hash)
    }
  end # def



end # module LaunchUp



end # module AE
