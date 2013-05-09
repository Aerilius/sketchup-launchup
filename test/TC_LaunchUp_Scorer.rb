require 'sketchup.rb'
require 'test/unit'



class TC_LaunchUp_Scorer < Test::Unit::TestCase



def setup
end



def teardown
end



def test_score_arguments # TODO
  #assert_nothing_raised() {}
  #assert_raises() {}

  # Zero lengths strings should be rejected with 0.0 score.
  search_word = ""
  string = "test"
  score = AE::LaunchUp::Scorer.score(search_word, string)
  assert(score == 0.0, "Zero lengths strings should be rejected with 0.0 score.")
  search_word = "test"
  string = ""
  score = AE::LaunchUp::Scorer.score(search_word, string)
  assert(score == 0.0, "Zero lengths strings should be rejected with 0.0 score.")

  # Identical strings should get a full score of 1.0.
  search_word = "test"
  string = "test"
  score = AE::LaunchUp::Scorer.score(search_word, string)
  assert(score == 1.0, "Identical strings should get a full score of 1.0.")

  # Test for unexpected behaviors with unicode strings.
  # Generate a string with many unicode characters.
  string = []
  1000.times{|i| string << i+32} # TODO: replace this by number where we get reasonable non-null characters
  string = string.pack("*U") << "test"
  search_word = "test"
  score = 0.0
  assert_nothing_raised("") { score = AE::LaunchUp::Scorer.score(search_word, string) }
  assert(score != 0.0, "")
end



def test_score_mistakes # TODO: Test on new words
  # search_word misses a character
  search_word = "tet" # 12 4
  string = "test"     # 1234
  score0 = AE::LaunchUp::Scorer.score(search_word, string)
  assert(0 < score0 && score0 < 1, "It should tolerate missing characters.")

  # search_word contains a character too much
  search_word = "tesat" # 12354
  string = "test"       # 123 4
  score1 = AE::LaunchUp::Scorer.score(search_word, string)
  assert(0 < score1 && score1 < 1, "It should tolerate single superfluous characters.")

  # one character is wrong between search_word and string
  search_word = "text" # 12 4
  string = "test"      # 12 4
  score2 = AE::LaunchUp::Scorer.score(search_word, string)
  assert(0 < score2 && score2 < 1, "It should tolerate single wrong characters.")

  # Too long series of disconnected characters should get a low score.
  search_word = "text"
  string = "three exceptions" # 1  2   3   4
  score3 = AE::LaunchUp::Scorer.score(search_word, string)
  assert(score3 < score1, "It should devalue long series of superfluous characters.")

  # TODO:
  # AE::LaunchUp::Scorer.score("text", "tbcd test")
  # AE::LaunchUp::Scorer.score("text", "abcd test")
end



def test_score_position
  # Match at beginning should get better score than match at new word.
  # Match at new word should get better score than match inbetween.
  search_word = "Test"
  string0 = "Test begin!"
  string1 = "second Test"
  string2 = "insideTest!"
  score0 = AE::LaunchUp::Scorer.score(search_word, string0, 0)
  score1 = AE::LaunchUp::Scorer.score(search_word, string1, 0)
  score2 = AE::LaunchUp::Scorer.score(search_word, string2, 0)
  assert(score0 > score1, "Match at beginning should get better score than match at new word.")
  assert(score1 > score2, "Match at new word should get better score than match inbetween.")
end



def test_score_case
  # Different case should get smaller score than same case.
  search_word0 = "Test"
  string0 = "Testing"
  search_word1 = "test"
  string1 = "testing"
  search_word2 = "Test"
  string2 = "testing"
  search_word3 = "test"
  string3 = "Testing"
  score0 = AE::LaunchUp::Scorer.score(search_word0, string0)
  score1 = AE::LaunchUp::Scorer.score(search_word1, string1)
  score2 = AE::LaunchUp::Scorer.score(search_word2, string2)
  score3 = AE::LaunchUp::Scorer.score(search_word3, string3)
  assert(score0 > score2, "Different case should get smaller score than same case.")
  assert(score1 > score2, "Different case should get smaller score than same case.")
  assert(score0 > score3, "Different case should get smaller score than same case.")
  assert(score1 > score3, "Different case should get smaller score than same case.")
end



def test_score_fuzziness_nil

end



def test_score_fuzziness_zero
end



def test_score_fuzziness_one
end



end # class TC_LaunchUp_Options
