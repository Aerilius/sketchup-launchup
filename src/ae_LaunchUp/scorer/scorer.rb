module AE



module LaunchUp



module Scorer

  SCORE_WORD_BEGIN = 1.5 unless defined?(self::SCORE_WORD_BEGIN)
  SCORE_MATCH      = 1.0 unless defined?(self::SCORE_MATCH)
  SCORE_NO_MATCH   = 0.0 unless defined?(self::SCORE_NO_MATCH)
  PENALTY_CASE     = 0.5 unless defined?(self::PENALTY_CASE)
  BONUS_BEGIN      = 0.15 unless defined?(self::BONUS_BEGIN)



  def self.score(abbreviation, string, fuzziness=nil)
    # If the string is equal to the abbreviation, perfect match.
    return 1.0 if string == abbreviation
    return 0.0 if !abbreviation.is_a?(String) || abbreviation.empty? ||
      !string.is_a?(String) || string.empty?

    abbreviation_orig = abbreviation.unpack("C*") # abbreviation.bytes.to_a
    abbreviation = abbreviation.downcase.unpack("C*") # abbreviation.downcase.bytes.to_a
    abbreviation_length = abbreviation.length

    string_orig = string.unpack("C*") # string.bytes.to_a
    string = string.downcase.unpack("C*") # string.downcase.bytes.to_a
    string_rest = string
    string_length = string.length.to_f
    index_in_string = 0
    index_in_abbrev = 0
    fuzzies = 0
    score_total = 0

    # Jump to first match.
    index_in_string = self.next_match(abbreviation[index_in_abbrev], index_in_string, string)

    while index_in_abbrev < abbreviation_length do

      # Match.
      if string[index_in_string] == abbreviation[index_in_abbrev]
        score_total += score_char(string_orig, index_in_string, abbreviation_orig[index_in_abbrev])

      # No match.
      elsif fuzziness
        #score_total -= 1

        # This character is wrong, but the next character is correct.
        if string[index_in_string+1] == abbreviation[index_in_abbrev+1]
          # Skip and continue with next.
          fuzzies += 1.0
          index_in_string += 1
          index_in_abbrev += 1
          score_total += score_char(string_orig, index_in_string, abbreviation_orig[index_in_abbrev])

        # It is missing but the next character is correct.
        elsif string[index_in_string] == abbreviation[index_in_abbrev+1]
          # Go to next in abbreviation.
          fuzzies += 1.0
          # index_in_string += 0
          index_in_abbrev += 1
          score_total += score_char(string_orig, index_in_string, abbreviation_orig[index_in_abbrev])

        # There is one wrong character inbetween.
        elsif string[index_in_string+1] == abbreviation[index_in_abbrev]
          # Skip and continue with next.
          fuzzies += 1.0
          index_in_string += 1
          # index_in_abbrev += 0
          score_total += score_char(string_orig, index_in_string, abbreviation_orig[index_in_abbrev])
        # Or we are at the end of consecutive characters (jump to next word).
        else
          fuzzies += 2.0
          # Jump to the next match.
          index_in_string = self.next_match(abbreviation[index_in_abbrev], index_in_string, string) if index_in_string < string.length
        end

      else # if no fuzziness
        score_total -= 1
        # Jump to the next match.
        index_in_string = self.next_match(abbreviation[index_in_abbrev], index_in_string, string) if index_in_string < string.length
      end

      # Next character.
      index_in_string += 1
      index_in_abbrev += 1
    end # while

    score_abbreviation = score_total / abbreviation_length

    # Reduce penalty for longer strings
    percentage_of_matched_string = abbreviation_length / string_length
    score_percentage = score_abbreviation * percentage_of_matched_string
    score_final = (score_percentage + score_abbreviation) / 2.0

    # Penalize any fuzzies
    # score_final = score_final * fuzziness + (1 - fuzziness) * (score_final / fuzzies)
    score_final = fuzziness + (1 - fuzziness) / fuzzies unless fuzzies == 0
    # Absolute beginning of string. Here it is not reduced due to string length.
    score_final += BONUS_BEGIN if string.first == abbreviation.first

    # Normalize.
    score_final = 0.0 if score_final < 0.0
    score_final = 1.0 if score_final > 1.0

    return score_final
  end



  def self.next_match(byte, index_in_string, string)
    return index_in_string if index_in_string > string.length
    othercase = (65..90).include?(byte) ? byte + 32 : (97..122).include?(byte) ? byte - 32 : nil
    string_rest = string.slice(index_in_string, string.length)
    indices = [string_rest.index(byte), string_rest.index(othercase)].compact
    index_in_rest = indices.min
    return (index_in_rest.nil?) ? index_in_string : index_in_string + index_in_rest
  end



  def self.score_char(string, index_in_string, char)
    # Very first character.
    #if index_in_string == 0
    #  score = SCORE_BEGIN
    #elsif
    # After a whitespace.
    if ((p=string[index_in_string-1]) == 32 || p == 9)
      score = SCORE_WORD_BEGIN
    # Within a word.
    else
      score = SCORE_MATCH
    end
    # Penalize different case (upper/lower case).
    score *= PENALTY_CASE if string[index_in_string] != char
    return score
  end
  private_class_method(:score_char)



end # module Scorer



end # module LaunchUp



end # module AE
