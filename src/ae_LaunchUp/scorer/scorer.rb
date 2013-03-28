module AE



module LaunchUp


=begin
Heavily customized algorithm, based on Matt Duncan's Scorer
https://github.com/mrduncan/scorer
###
Copyright (c) 2011 Matt Duncan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
=end

module Scorer

  SCORE_BEGIN      = 2.0 unless defined?(self::SCORE_BEGIN)
  SCORE_WORD_BEGIN = 1.5 unless defined?(self::SCORE_WORD_BEGIN)
  SCORE_MATCH      = 1.0 unless defined?(self::SCORE_MATCH)
  SCORE_ACRONYM    = 1.0 unless defined?(self::SCORE_ACRONYM)
  SCORE_NO_MATCH   = 0.0 unless defined?(self::SCORE_NO_MATCH)
  PENALTY_DISTANCE = 0.5 unless defined?(self::PENALTY_DISTANCE)
  PENALTY_CASE     = 0.8 unless defined?(self::PENALTY_CASE)
  PENALTY_FUZZY    = 1.0 unless defined?(self::PENALTY_FUZZY)
  BONUS_BEGIN      = 0.15 unless defined?(self::BONUS_BEGIN)

  def self.score(abbreviation, string, fuzziness=nil)
    # If the string is equal to the abbreviation, perfect match.
    return 1.0 if string == abbreviation
    return 0.0 if !abbreviation.is_a?(String) || abbreviation.empty? ||
      !string.is_a?(String) || string.empty?

    abbreviation = abbreviation.unpack("C*") # .bytes.to_a
    abbreviation_length = abbreviation.length
    string = string.unpack("C*") # .bytes.to_a
    string_length = string.length.to_f

    fuzzies = 0
    index_last = -1
    index_in_string = 0
    indexes = nil
    score = 0.0
    score_total = 0.0

    # Walk through abbreviation and add up scores.
    first_char_in_abbreviation = true
    abbreviation.each{ |byte|
      # Find the index of current character (case-insensitive) in remaining part
      # of string.
      othercase = (65..90).include?(byte) ? byte + 32 : (97..122).include?(byte) ? byte - 32 : nil
      indexes = [string.index(byte), string.index(othercase)].compact
      index_in_string = indexes.min

      # No match:
      if index_in_string.nil?
        # Abbreviation doesn't match entirely, so return.
        return 0.0 unless fuzziness
        # Or be forgiving if fuzziness is allowed.
        fuzzies += 1.0 - fuzziness
        next
      # Match:
      else
        # Base score depending on position:
        if index_in_string == 0
          # Absolute beginning of string.
          if first_char_in_abbreviation == true
            score = SCORE_BEGIN
          # After a whitespace.
          elsif ((p=string[index_in_string-1]) == 32 || p == 9) #&& (byte_last == 32 || byte_last == 9)# or index_last?
            score = SCORE_WORD_BEGIN
          else
          # Consecutive letter within a word.
            score = SCORE_MATCH
          end
        else # some letters skipped:
          # New word
          if ((p=string[index_in_string-1]) == 32 || p == 9) #&& (byte_last == 32 || byte_last == 9)# or index_last?
            score = SCORE_WORD_BEGIN
          # Acronym
          elsif (65..90).include?(byte) && (65..90).include?(string[index_in_string])
            score = SCORE_ACRONYM
          # Random letter, but penalize the distance from previous match.
          else
            score = SCORE_MATCH
            # (except if there is no previous match)
            fuzzies += index_in_string * PENALTY_DISTANCE unless index_last == -1
          end
        end

        # Penalize different case (upper/lower case).
        score *= PENALTY_CASE if string[index_in_string] != byte

        # Left trim the matched part of the string
        # (forces sequential matching).
        string = string.slice(index_in_string + 1, string_length)

        # Add to total character score.
        score_total += score
        index_last = index_in_string
        first_char_in_abbreviation = false
      end # if match
    } # each

    score_abbreviation = score_total / abbreviation_length

    # Reduce penalty for longer strings
    percentage_of_matched_string = abbreviation_length / string_length
    score_percentage = score_abbreviation * percentage_of_matched_string
    score_final = (score_percentage + score_abbreviation) / 2.0

    # Penalize any fuzzies
    score_final /= (1 + fuzzies * PENALTY_FUZZY) unless fuzzies == 0
    # Absolute beginning of string. Here it is not reduced due to string length.
    score_final += BONUS_BEGIN if string.first == abbreviation.first
    score_final = 1.0 if score_final > 1.0

    return score_final
  end

end # module Scorer



end # module LaunchUp



end # module AE
