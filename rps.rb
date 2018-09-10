require 'rubocop'
require 'pry'

module Display
  def clear_screen
    system('clear') || system('cls')
  end

  def prompt(message)
    puts "=> #{message}"
  end
end

class Move
  attr_reader :value
  WIN_CONDITIONS = { "rock" => %w(scissors lizard),
                     "paper" => %w(rock spock),
                     "scissors" => %w(paper lizard),
                     "lizard" => %w(paper spock),
                     "spock" => %w(rock scissors) }.freeze

  def initialize(value)
    @value = value
  end

  def >(other_move)
    WIN_CONDITIONS[value].include? other_move.value
  end

  def <(other_move)
    WIN_CONDITIONS[other_move.value].include? value
  end

  def to_s
    @value
  end
end

class Player
  include Display
  attr_accessor :move, :name, :score

  def initialize
    set_name
    @score = 0
  end
end

class Human < Player
  CONVERT_CHOICE = { "r" => "rock",
                     "p" => "paper",
                     "s" => "scissors",
                     "l" => "lizard",
                     "k" => "spock" }.freeze
  def set_name
    n = ''
    loop do
      prompt("What's your name?")
      n = gets.chomp
      break unless n.empty?
      prompt('Sorry, must enter a name.')
    end
    self.name = n
  end

  def choose
    choice = nil
    loop do
      prompt("Please choose (r)ock, (p)aper, (s)cissors, (l)izard, or spoc(k):")
      choice = gets.chomp
      break if CONVERT_CHOICE.keys.include? choice
      prompt("Sorry, invalid choice.")
    end
    choice = CONVERT_CHOICE[choice]
    self.move = Move.new(choice)
  end
end

class Computer < Player
  def set_name
    self.name = self.class.to_s
  end

  def losing_rounds(data)
    data.select { |round| round[:result] == :human }
  end
end

# R2D2 will only ever use the human's current move or most recent move
class R2D2 < Computer
  def welcome_message
    prompt("Prepare to play #{name} - he doesn't have the best memory!")
  end

  def choose(data, human_move)
    if data.length.nonzero?
      self.move = Move.new(([data[-1][:human]] + [human_move.value]).sample)
    else
      self.move = Move.new(human_move.value)
    end
  end
end

# Hal will play random moves unless human gets to 4 points,
# then becomes invincible
class Hal < Computer
  def welcome_message
    prompt("Prepare to play #{name} - he'll let you hope!")
  end

  def choose(data, human_move)
    if losing_rounds(data).length == 4
      possible_moves = Move::WIN_CONDITIONS.select do |_, value|
        value.include? human_move.value
      end
      self.move = Move.new(possible_moves.keys.sample)
    else
      self.move = Move.new(Move::WIN_CONDITIONS.keys.sample)
    end
  end
end

# Watson will minimize losing moves by looking at human's winning moves
# and adjusting weights for random sample
class Watson < Computer
  def welcome_message
    prompt("Prepare to play #{name} - be unpredictable")
  end

  def choose(data, _)
    if losing_rounds(data).length.zero?
      self.move = Move.new(Move::WIN_CONDITIONS.keys.sample)
    else
      weighted = minimize_losing_moves(data)
      self.move = Move.new(weighted_random_sample(weighted.shuffle))
    end
  end

  def minimize_losing_moves(data)
    losing_rounds = losing_rounds(data)
    human_win_moves = human_win_moves(losing_rounds)
    losing_moves = losing_moves(human_win_moves)
    frequency = frequency(losing_moves)
    frequency = fill_in_moves(frequency)
    convert_to_weighted(frequency)
  end

  def human_win_moves(rounds)
    rounds.each_with_object(Hash.new(0)) do |round, hash|
      hash[round[:human]] += 1
    end
  end

  def losing_moves(moves)
    moves.each_with_object(Array.new) do |(move, num), array|
      num.times { array << Move::WIN_CONDITIONS[move] }
    end
  end

  def frequency(moves)
    moves.flatten.each_with_object(Hash.new(0)) do |move, hash|
      hash[move] += 1
    end
  end

  def fill_in_moves(frequency)
    Move::WIN_CONDITIONS.keys.each do |move|
      frequency[move] = 0 if !frequency.keys.include? move
    end
    frequency
  end

  def convert_to_weighted(hash)
    sum = hash.inject(0) do |total, move_and_value|
      total + move_and_value[1].to_f
    end
    hash.each do |move, weight|
      hash[move] = (1 - weight / sum)**2
    end
    hash.to_a
  end

  def weighted_random_sample(weighted)
    target = rand
    weighted.each do |move, weight|
      return move if target <= weight
      target -= weight
    end
  end
end

class History
  include Display
  attr_accessor :data, :round

  def initialize
    @data = []
    @round = 0
  end

  def update(outcome, human, computer)
    round += 1
    data << { round: self.round,
              result: outcome,
              human: human,
              computer: computer }
  end

  def display(human, computer)
    symbols = { human: '<-', computer: '->', tie: '--' }
    prompt("----- GAME HISTORY ------")
    prompt("Round # - #{human} // #{computer}")
    data.last(5).each do |round|
      num = round[:round]
      human = round[:human]
      symbol = symbols[round[:result]]
      computer = round[:computer]
      prompt("#{num} - #{human} /#{symbol}/ #{computer}")
    end
  end

  def winning_moves(player)
    winning_rounds = data.select { |round| round[:result] == player }
    winning_rounds.each_with_object(Hash.new(0)) do |round, hash|
      hash[round[player]] += 1
    end
  end
end

class RPSGame
  include Display
  attr_accessor :human, :computer, :history

  def initialize
    @human = Human.new
    @computer = [R2D2, Watson, Hal].sample.new
    @history = History.new
  end

  def start_game
    reset_score
    reset_history
    display_welcome_message
  end

  def reset_score
    human.score = 0
    computer.score = 0
  end

  def reset_history
    history.data = []
  end

  def display_welcome_message
    prompt("Welcome to Rock, Paper, Scissors, Lizard, Spock!")
    computer.welcome_message
  end

  def moves
    human_move = human.choose
    computer.choose(history.data, human_move)
  end

  def display_goodbye_message
    prompt("Goodbye!")
  end

  def display_moves
    clear_screen
    prompt("#{human.name} chose #{human.move}.")
    prompt("#{computer.name} chose #{computer.move}.")
  end

  def result
    if human.move > computer.move
      human_win
    elsif human.move < computer.move
      computer_win
    else
      tie
    end
  end

  def human_win
    prompt("#{human.name} won!")
    human.score += 1
    history.update(:human, human.move.value, computer.move.value)
  end

  def computer_win
    prompt("#{computer.name} won!")
    computer.score += 1
    history.update(:computer, human.move.value, computer.move.value)
  end

  def tie
    prompt("It's a tie!")
    history.update(:tie, human.move.value, computer.move.value)
  end

  def display_score
    prompt("#{human.name}: #{human.score}, #{computer.name}: #{computer.score}")
  end

  def display_history
    history.display(human.name, computer.name)
  end

  def play_again?
    answer = nil
    loop do
      prompt("Would you like to play again? (y/n)")
      answer = gets.chomp
      break if ['y', 'n'].include? answer.downcase
      prompt("Sorry, must be y or n.")
    end

    return false if answer.casecmp('n').zero?
    return true if answer.casecmp('y').zero?
  end

  def play
    loop do
      start_game
      loop do
        moves
        display_moves 
        result
        display_score
        display_history
        break if human.score == 5 || computer.score == 5
      end
      prompt('Game complete!')
      break unless play_again?
    end
    display_goodbye_message
  end
end

RPSGame.new.play
