require 'set'
require './features.rb'
require './averagedPerceptron.rb'

$DEBUG = true
JSON_DATA = "/data/tagged-data.json"
AP_MODEL_LOC = Dir.pwd + JSON_DATA
TAGGED_WORD_RE = /\((\S+)\s+(\S+)\)/ # how to split the text data

class String
  def normalize
    # Normalization used in pre-processing.
    # - All words are lower cased
    # - Digits in the range 1800-2100 are represented as !YEAR;
    # - Other digits are represented as !DIGITS
    # :rtype: str
    if self.include?("-") and self[0] != "-"
      return "!HYPHEN"
    elsif self =~ /^([1-2][0-9])[0-9]{2}$/
      return '!YEAR'
    elsif self[0] =~ /^[0-9]+$/
      return '!DIGITS'
    else
      return self.downcase
    end
  end
end

class PerceptronTagger
  # Greedy Averaged Perceptron tagger, as implemented by Matthew Honnibal.
  # See more implementation details here:
  #   http://honnibal.wordpress.com/2013/09/11/a-good-part-of-speechpos-tagger-in-about-200-lines-of-python/
  # :param load: Load the pickled model upon instantiation.

  START = ["-START-", "-START2-"]
  ENDS = ["-END-", "-END2-"]

  def initialize
    @model = AveragedPerceptron.new
    @@tagdict = Hash.new
    @classes = Set.new
    #load(AP_MODEL_LOC)
    puts "---------------------------------------"
    $stderr.puts("PerceptronTagger initialized")
    print("@model: ", @model, "\n")
    print("@@tagdict: ", @@tagdict, "\n")
    print("@classes: ", @classes, "\n")
    puts "---------------------------------------"
  end

  attr_accessor :model, :tagdict, :classes

  def tag(corpus)
    # Tags a string `corpus`.
    # Assume untokenized corpus has \n between sentences and ' ' between words
    # Returns array of (WORD, TAG)
    $stderr.puts("PerceptronTagger.tag called")
    prev, prev2 = START
    tokens = []

    wordArray = corpus.split("\n").map(&:split)
    wordArray.each do |words|
      context = START + words.map(&:normalize) + ENDS
      print("context: ", context, "\n")
      wordArray.each_with_index do |word, index|
        print("i: ",index,"\n")
        print("word: ",word,"\n")
        word.each do |sym|
          print("to_sym: ",sym.to_sym, "\n")
          print("@@tagdict:", @@tagdict, "\n")
          _tag = @@tagdict[sym.to_sym]
          print("_tag: ", _tag, "\n")
          if _tag != nil
            features = getFeatures(i, word, context, prev, prev2)
            tag = @model.predict(features)
          end
          tokens << [word, _tag]
          prev2 = prev
          prev = _tag
        end
      end
    end
    print("tokens: ", tokens, "\n")
    return tokens
  end

  def train(sentences, saveLoc=nil, nrIter=5)
    # Train a model from sentences, and save it at ``save_loc``. ``nr_iter``
    # controls the number of Perceptron training iterations.
    # :param sentences: A list of (words, tags) tuples.
    # :param save_loc: If not ``None``, saves a pickled model in this location.
    # :param nr_iter: Number of training iterations.
    makeTagdict(sentences)
    @model.classes = @classes

    nrIter.times do |i|
      c = 0
      n = 0
      sentences.each do |words, tags|
        prev, prev2 = START
        context = START + words.map(&:_normalize) + ENDS
        words.each_with_index do |word, i|
          guess = @@tagdict[word.to_sym]
          if not guess
            feats = getFeatures(i, word, context, prev, prev2)
            guess = @model.predict(features)
            @model.update(tags[i], guess, feats)
          end
          prev2 = prev
          prev = guess
          c += 1 if guess == tags[i]
          n += 1
        end
        sentences.shuffle!
        $stderr.puts("Iteration #{i}: #{c}/#{n}=#{_pc(c,n)}")
      end
    end
    @model.average_weights()

    # Save as JSON file
    if not saveLoc
      $stderr.puts("Saving JSON file...")
      #File.open(path, 'w') do |file|
      #  JSON.dump(hash, file)
      #end
    end
    return nil
  end

  def load(loc)
    $stderr.puts("PerceptronTagger.load called")
    # Load a tagged model.
    # Assume that the form is (TAG WORD).
    weightTagClass = []
    @weight = []
    begin
      File.open(loc, 'rb') do |file|
        file.each_line.map do |line|
          weightTagClass = line.scan(TAGGED_WORD_RE)
          weightTagClass.each do |str|
            tag = weightTagClass[0].to_sym
            word = weightTagClass[1]
            #@weights =
            @@tagdict[tag] = word
            @classes << weightTagClass[0]
          end
        end
      end
    rescue SystemCallError => e
      puts %Q(class=[#{e.class}] message=[#{e.message}])
    rescue IOError => e
      puts %Q(class=[#{e.class}] message=[#{e.message}])
    end
    # @weights, @@tagdict, @classes = w_td_c
    @model.classes = @classes
    return nil
  end


  def makeTagdict(sentences)
    # Make a tag dictionary for single-tag words.
    counts = Hash.new {|h,k| h[k] = Hash.new(0); 0}
    sentences.each do |words, tags|
      words.zip(tags).each do |word, tag|
        counts[:word][:tag] += 1
        @classes.addFeature!(tag)
      end

      freq_thresh = 20
      ambiguity_thresh = 0.97

      counts.each do |word, tagFreq|
        tag, mode = tagFreq.each.max{|x,y| x[1] <=> y[1]}
        n = tagFrew.values.sum
        # Don't add rare words to the tag dictionary
        # Only add quite unambiguous words
        if n >= freq_thresh and (mode.to_f / n) >= ambiguity_thresh then
          @@tagdict[word] = tag
        end
      end
    end
  end

  def _pc(n, d)
    return (n.to_f / d) * 100
  end

end


#$stderr.puts("Main function called...")
#tagger = PerceptronTagger.new
#tagger.load(JSON_DATA)
#print(tagger.tag("How are you?\nI'm fine\nAnd you?"))
#$stderr.puts("Start testing...")
#right = 0.0
#total = 0.0
#sentence = [[], []]
#begin
#  filename = "data/test.pos"
#  File.open(filename, "r") do |file|
#    file.each_line do |param|
#      params = param.split("\n")
#      if params.length != 2 then next
#        sentence[0] << params[0]
#        sentence[1] << params[1]
#        if params[0] == "." then
#          text = ""
#          words = sentence[0]
#          tags = sentence[1]
#          words.length.times do |i|
#            text += words[i]
#            text += ' ' if i < words.length
#          end
#          outputs = tagger.tag(text)
#          assert len(tags) == len(outputs)
#          total += len(tags)
#          outpus.zip(tags).each do |o, t|
#            right += 1 if o[1].strip() == t
#          end
#          sentence = [[], []]
#        end
#        $stderr.puts("Precision: #{right / total}")
#      end
#    end
#  end
#
#  # Except
#rescue IOError => e
#  puts %Q(class=[#{e.class}] message=[#{e.message}])
#end
#$stderr.puts("Reading corpus...")
#training_data = []
#sentence = [[], []]
#filename = "data/train.pos"
#File.open(filename, "r") do |file|
#  file.each_line.map do |param|
#    params = param.scan(TAGGED_WORD_RE)
#    p params
#    sentence[0] << params[0]
#    sentence[1] << params[1]
#    if params[0] == '.' then
#      training_data << sentence
#      sentence = [[], []]
#    end
#    $stderr.puts("training corpus size : #{training_data.length}")
#    $stderr.puts("Start training...")
#    tagger.train(training_data, saveLoc=JSON_DATA)
#  end
#end
