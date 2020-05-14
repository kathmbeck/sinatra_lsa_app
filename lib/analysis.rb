require "engtagger"

MORPHEME_KEY = { UH: 0, SYM: 0, PP: 0, PPC: 0, PPD: 0, PPL: 0, PPR: 0, PPS: 0,
                 LRB: 0, RRB: 0, CC: 1, CD: 1, DET: 1, EX: 1, IN: 1, JJ: 1, FW: 1,
                 MD: 1, NN: 1, NNP: 1, PDT: 1, POS: 1, PRP: 1, PRPS: 1, RB: 1, RP: 1,
                 TO: 1, VB: 1, VBP: 1, WDT: 1, WP: 1, WPS: 1, WRB: 1, JJR: 2,
                 JJS: 2, RBR: 2, RBS: 2, VBG: 2
               }

AVERAGE_MLU = { (36..41) => "4.24 (2.87 - 5.61)",
                (42..47) => "5.41 (4.13 - 6.69)",
                (48..53) => "5.79 (4.26 - 7.32)",
                (54..59) => "6.18 (4.86 - 7.50)",
                (60..71) => "6.66 (5.31 - 8.01)",
                (72..83) => "7.60 (6.00 - 9.20)",
                (84..95) => "8.19 (6.87 - 9.33)"
              }

def all_words(transcript)
  transcript.join(' ')
end

def total_word_count(transcript)
  all_words(transcript).split(' ').size
end

def total_different_words(transcript)
  all_words(transcript).split(' ').uniq.size
end

def type_token_ratio(transcript)
  tdw = total_different_words(transcript).to_f
  tw = total_word_count(transcript).to_f
  (tdw / tw).round(2)
end

def find_mean_mlu_for_age(years, months)
  age_in_months = (years * 12) + months
  string =''
  AVERAGE_MLU.keys.each do |range|
    string = AVERAGE_MLU[range] if range.include?(age_in_months)
  end
  string
end


def tag_language_sample(text)
  tgr = EngTagger.new
  p text.map { |utterance| tgr.get_readable(utterance).split }
end

def evaluate_noun(word)
  original_word = word.split("/").first
  original_word.end_with?("s") ? 2 : 1
end

def evaluate_present_verb(word)
  original_word = word.split("/").first
  exceptions = ['is', 'has']
  exceptions.include?(original_word) ? 1 : 2
end

def evaluate_past_verb(word)
  word.end_with?("ed") ? 2 : 1
end

def evaluate_morphemes(word)
  tag = word.split('/').last.to_sym
  return MORPHEME_KEY[tag] if MORPHEME_KEY.keys.include?(tag)
  if tag == :NNPS || tag == :NNS
    evaluate_noun(word)
  elsif tag == :VBZ
    evaluate_present_verb(word)
  elsif tag == :VBD || tag == :VBN
    evaluate_past_verb(word)
  else
    0
  end
end

def count_morphemes_per_word(text)
  tagged_text = tag_language_sample(text)
  tagged_text.map do |utterance|
    utterance.map! do |word|
      evaluate_morphemes(word)
    end
  end
end

def calculate_mlu(text)
  word_morpheme_counts = count_morphemes_per_word(text)
  total_morphemes = word_morpheme_counts.map { |utterance| utterance.sum }.sum.to_f
  total_utterances = word_morpheme_counts.size.to_f
  (total_morphemes/total_utterances).round(2)
end