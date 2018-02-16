class Features
  SUFFIX_LENGTH = 3

  def initialize
    @features = Hash.new{0} # default value is 0
  end
  attr_accessor :features

  def suffix(word)
    word[ [0, word.length-SUFFIX_LENGTH].max ]
  end

  # Get features
  # i:       int
  # word:    string
  # context: array of string
  # prev:    string
  # prev2:   string
  def getFeatures(i, word, context, prev, prev2)

    # Add feature value
    # This is a bang method
    # name: String
    # args: String, String, ...
    def addFeature!(name, *args)
      @features[(name + " " + args.join(" ")).to_sym] += 1
      return @features
    end

    addFeature!("bias")

    addFeature!("i suffix", suffix(word))
    addFeature!("i pref1", word[0].to_s)

    addFeature!("i-1 tag", prev)
    addFeature!("i-2 tag", prev2)
    addFeature!("i tag+i-2 tag", prev, prev2)

    addFeature!("i word", context[i])
    addFeature!("i-1 tag+i word", prev, context[i])

    addFeature!("i-1 word", context[i-1])
    addFeature!("i-1 suffix", suffix(context[i-1]))

    addFeature!("i-2 word", context[i-2])

    addFeature!("i+1 word", context[i+1])
    addFeature!("i+1 suffix", suffix(context[i+1]))

    addFeature!("i+2 word", context[i+2])
  end
end
