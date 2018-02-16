require 'optparse'
autoload :JSON, 'json'
autoload :Set, 'set'
autoload :OpenStruct, 'ostruct'
autoload :Perceptron, './perceptron'


class IO
  # Prints the provided array of pairs to match the format of the corpora.
  def print_in_corpus_format(ary)
    puts ary.map { |tag,word| "(#{tag} #{word})"}.join(" ")
  end
end


class POSTagger
  def log(str)
    $stderr.puts(str) if $DEBUG
  end

  # Default files to find corpus.
  DEFAULT_TRAINING_CORPUS = "data/f2-21-train.pos"
  DEFAULT_TEST_CORPUS     = "data/f2-21-test.pos"

  # Format of a single tagged word within the corpus.
  TAGGED_WORD_RE = /\((\S+)\s+(\S+)\)/

  # Initialize the tagger from a corpus file.
  def initialize(filename, frozen_model=false)
    log "Method in use: #{method2str}"
    if frozen_model
      rehydrate_model_from(filename)
    else
      read_training_corpus(filename)
    end
  end

  # Restore the tagger from the provided file.
  def rehydrate_model_from(filename)
    log("Reading saved #{method2str} model from #{filename}.")
    File.open(filename, "r") do |file|
      @model = JSON.parse(file.read)
    end
  end

  def save_to_json(filename=default_json_filename)
    @model.save_to_json(filename)
  end

  # Read command line options and run program.
  def self.main(*args)
    options = {
      :training_corpus => DEFAULT_TRAINING_CORPUS,
      :test_corpus     => DEFAULT_TEST_CORPUS,
      :debug           => $DEBUG,
      :frozen_tagger   => nil
    }

    (OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options] [-h for help]"

      opts.on("-r", "--training-corpus [PATH]", String,
              "Path to file containing training corpus;\n\t" +
              " #{DEFAULT_TRAINING_CORPUS} by default.") do |v|
        options[:training_corpus] = v
      end
      opts.on("-e", "--test-corpus [PATH]", String,
              "Path to file containing test corpus;\n\t" +
              " #{DEFAULT_TEST_CORPUS} by default.") do |v|
        options[:test_corpus] = v
      end
      opts.on("-d", "--[no-]debug", "Set debug mode.") do |v|
        options[:debug] = v
      end
      opts.on("-f", "--tagger-file [FILE]", "Use stored file instead\n\t" +
              "of reading in a training corpus.") do |f|
        options[:frozen_tagger] = f
      end
      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit()
      end
    end).parse!

    # Check for existence of files
    if options[:frozen_tagger].nil? # We need a training corpus
      unless File.exist? options[:training_corpus]
        puts "#{options[:training_corpus]} does not exist."
        exit()
      end
    else
      unless File.exist? options[:frozen_tagger]
        puts "#{options[:frozen_tagger]} does not exist."
        exit()
      end
    end
    unless File.exist? options[:test_corpus]
      puts "#{options[:test_corpus]} is not a directory."
      exit()
    end
    $DEBUG = options[:debug]
    tagger = nil

    fraction_good = tagger.evaluate(options[:test_corpus])
    puts "Model evaluated %.4f%% of tags correctly." % (fraction_good * 100.0)
  end
end


class PerceptronTagger < POSTagger
  # Readable version of the tagging method
  def method2str()
    "Perceptron"
  end

  # Default file name for saving model to JSON
  def default_json_filename()
    Perceptron::DEFAULT_JSON_FILENAME
  end

  # Reads a single corpus file. Returns all the pairs of words.
  def read_corpus_file(corpus)
    return File.open(corpus) do |file|
      file.each_line.map do |line|
        line.scan(TAGGED_WORD_RE)
      end
    end
  end

  # Reads in the data from a corpus file.
  def read_training_corpus(training_corpus)
    @training_set = read_corpus_file(training_corpus)
    log "Creating and training Perceptron Model"
    train_perceptron()
    log "Successfully trained Perceptron Model"
  end

  # Create the perceptron for this data and train it
  def train_perceptron()
    log "train_perceptron() called"
    @model = Perceptron.new()
    @model.train(@training_set)
  end

  # Evaluate the generated model against the provided test corpus.
  # Returns the number of correct tags.
  def evaluate(test_corpus)
    log "Evaluating model against #{test_corpus}"
    num_right = 0
    num_possible = 0
    outfile_name = "data/output-perceptron.txt"
    # Read file
    File.open(test_corpus) do |file|
      File.open(outfile_name, "w+") do |outfile|
        log "Writing results to file #{outfile_name}."
        # Read lines.
        file.readlines.each do |line|
          # Extract tagged words.
          tagged_words = line.scan(TAGGED_WORD_RE)
          # Now just the words.
          just_the_words = tagged_words.map do |tag,word|
            word
          end
          states_guess = @model.states_of_events(just_the_words)
          outfile.print_in_corpus_format(states_guess.zip(just_the_words))
          states_guess.each_with_index do |state,index|
            num_right += 1 if state == tagged_words[index][0]
            num_possible += 1
          end
        end
      end
    end
    log "Tagged #{num_right} correctly out of a possible #{num_possible}."
    return Float(num_right) / num_possible
  end
end

# Start the script.
POSTagger.main(ARGV) if $0 == __FILE__
