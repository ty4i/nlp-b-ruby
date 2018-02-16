require 'set'
require 'json'

class AveragedPerceptron
  # An averaged perceptron, as implemented by Matthew Honnibal.
  # See more implementation details here:
  # http://honnibal.wordpress.com/2013/09/11/a-good-part-of-speechpos-tagger-in-about-200-lines-of-python/

  def initialize
    # Each feature gets its own weight vector, so weights is a dict-of-dicts
    @weights = {}
    @classes = Set.new

    # The accumulated values, for the averaging. These will be keyed by
    # feature/clas tuples
    @_totals = Hash.new(0)

    # The last time the feature was changed, for the averaging. Also
    # keyed by feature/clas tuples
    # (tstamps is short for timestamps)
    @_tstamps = Hash.new(0)

    # Number of instances seen
    @i = 0
  end
  attr_accessor :weights, :classes

  def predict(features)
    # Dot-product the features and current weights and return the best label.
    scores = Hash.new(0.0)
    features.each do |feat, value|
      if @weights.has_key?(feat) || value == 0
        next
      end
      _weights = @weights[feat]
      Array(_weights).each do |label, weight|
        scores[label] += value * weight
        # Do a secondary alphabetic sort, for stability
      end
    end
    return @classes.max{ |x, y| x[1] <=> y[1] }
  end

  def update(truth, guess, features)
    # Update the feature weights
    def upd_feat(c, f, w, v)
      param = [f, c]
      @_totals[param] += (@i - @_tstamps[param]) * w
      @_tstamps[param] = @i
      @weights[f][c] = w + v
    end

    @i += 1
    if truth == guess
      return nil
    end
    features.each do |f|
      #weights = self.weights.setdefault(f, {})
      #upd_feat(truth, f, weights.get(truth, 0.0), 1.0)
      #upd_feat(guess, f, weights.get(guess, 0.0), -1.0)
    end
    return nil
  end

  def average_weights
    # Average weights from all iterations.
    @weights.each do |feat, weights|
      new_feat_weights = {}
      weights.each do |clas, weight|
        param = [feat, clas]
        total = @_totals[param]
        total += (@i - @_tstamps[param]) * weight
        averaged = (total / @i.to_f).round(3)
        new_feat_weights[clas] = averaged if averaged
      end
      @weights[feat] = new_feat_weights
    end
    return nil
  end

  def save(path)
    # Save the pickled model weights.
    File.open(path, 'w') do |file|
      JSON.dump(hash, file)
    end
    $stderr.puts("Saving file...")
  end

  def load(path)
    # Load the pickled model weights.
    weightTagClass = open(path) do |file|
      JSON.load(file)
    end
    @weights = weightTagClass[0]
    return nil
  end
end


def train(nr_iter, examples)
  # Return an averaged perceptron model trained on ``examples`` for
  # ``nr_iter`` iterations.
  model = AveragedPerceptron.new
  features = []
  nr_iter.times do
    examples = examples.to_a.shuffle
    examples.each do |key,value|
      features << key.to_s
      p features
      class_ = value
      scores = model.predict(features)
      guess = scores.max{ |x, y| x[1] <=> y[1] }[0] unless guess.nil?
      score = scores.max{ |x, y| x[1] <=> y[1] }[1] unless guess.nil?
      if guess != class_
        model.update(class_, guess, features)
      end
    end
  end
  model.average_weights()
  return model
end

#train(5,["We", "are", "the", "world"])
