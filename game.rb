# frozen_string_literal: true

require './board.rb'
require './game_state.rb'
require './player.rb'
require './game_rule.rb'
require './computer_player.rb'
require 'discordrb'

TOKEN = ''
ID = 0

@bot = Discordrb::Commands::CommandBot.new(
  token: TOKEN,
  client_id: ID,
  prefix: 'o-x!'
)

# gamemode 1: 2players, 2:single, 3:cpu_vs_cpu
# difficulty 1:hard 2:soft
# order_to_attack 0:first, 1 second
def define(game_mode:, difficulty:, order_to_attack:)
  if order_to_attack.negative? || order_to_attack > 1
    raise ArgumentError, '0 is first, 1 is second'
    end

  @board = Board.new(board_size: 3)
  @stat = GameState.new(order_to_attack)
  @order_to_attack = order_to_attack
  @difficulty = difficulty
  @judge = GameRule.new(game_board: @board.board)
  @game_mode = game_mode
  create_game_with_game_mode(game_mode)
end

def copy_emoji_array(board)
  index_x = 0
  board.map do |line|
    line.map do |value|
      index_x += 1
      emoji = ''
      if value == '.'
        case index_x
        when 1
          emoji = 'one'
        when 2
          emoji = 'two'
        when 3
          emoji = 'three'
        when 4
          emoji = 'four'
        when 5
          emoji = 'five'
        when 6
          emoji = 'six'
        when 7
          emoji = 'seven'
        when 8
          emoji = 'eight'
        when 9
          emoji = 'nine'
        end
        emoji
      else
        value
      end
    end
  end
end

def create_game_with_game_mode(game_mode)
  if game_mode == 1
    @player1 = Player.new(mark: 'o', board: @board, game_state: @stat)
    @player2 = Player.new(mark: 'x', board: @board, game_state: @stat)
  elsif game_mode == 2
    @player1 = Player.new(mark: 'o', board: @board, game_state: @stat)
    @player2 = ComputerPlayer.new(mark: 'x', opponent_mark: @player1.mark, board: @board, game_state: @stat)
  else
    @player1 = ComputerPlayer.new(mark: 'o', opponent_mark: 'x', board: @board, game_state: @stat)
    @player2 = ComputerPlayer.new(mark: 'x', opponent_mark: @player1.mark, board: @board, game_state: @stat)
  end
end

def print_board(board, event)
  emoji_board = copy_emoji_array board
  text = <<-EOS
  :#{emoji_board[0][0]}::#{emoji_board[0][1]}::#{emoji_board[0][2]}:
  :#{emoji_board[1][0]}::#{emoji_board[1][1]}::#{emoji_board[1][2]}:
  :#{emoji_board[2][0]}::#{emoji_board[2][1]}::#{emoji_board[2][2]}:
  EOS

  event.send_embed do |embed|
    embed.description = text
    embed.title = "Turn:#{@stat.turn}"
    embed.color = 0x3BFB00
  end
end

def cpu_v_cpu
  loop do
    if @stat.first_player_turn?
      @player1.put(game_board: @board.board)
    else
      @player2.put(game_board: @board.board)
    end
    @board.print_board
    puts ''
    if @judge.mark_align?('o')
      puts 'o win!'
      exit
    elsif @judge.mark_align?('x')
      puts 'x win!'
      exit
    elsif @judge.all_squares_marked?
      puts 'draw'
      exit
    end
  end
end

def p_vs_cpu(event, x = 0, y = 0)
  if @stat.turn % 2 == @order_to_attack && @is_inputed == false
    print_board @board.board, event
    @bot.send_message @channel,
'置く位置を選んで下さい。
選んだら１〜９を`o-x!put 4`のように入力して下さい。'
    return
  end
  x = x.to_i
  y = y.to_i
  begin
    if @stat.turn % 2 == @order_to_attack && @is_inputed
      @player1.put(x: x, y: y)
      print_board @board.board, event
    else
      @bot.send_message @channel, 'AIのターン'
      @player2.put(game_board: @board.board) if @difficulty == 1
      @player2.put_softly(game_board: @board.board) if @difficulty == 2
      @is_inputed = false
      print_board @board.board, event
      unless @judge.mark_align?('o') || @judge.mark_align?('x') || @judge.all_squares_marked?
        @bot.send_message @channel,
'置く位置を選んで下さい。
選んだら１〜９を`o-x!put 4`のように入力して下さい。'
      end
    end
  rescue ArgumentError => e
    @bot.send_message @channel, '入力が不正です'
    return
  end
  if @judge.mark_align?('o')
    @bot.send_message @channel, 'o win!'
    @is_game_start = false
    init
    return
  elsif @judge.mark_align?('x')
    @bot.send_message @channel, 'x win!'
    @is_game_start = false
    init
    return
  elsif @judge.all_squares_marked?
    @bot.send_message @channel, 'draw'
    @is_game_start = false
    init
    return
  end
  p_vs_cpu event if @is_inputed
end

def init
  @is_inputed = false
  @already_started = false
  @is_game_start = false
  define(game_mode: @game_mode, difficulty: @difficulty, order_to_attack: @order_to_attack)
end

def p_vs_p(event, x, y)
  x = x.to_i
  y = y.to_i
  begin
    if @stat.first_player_turn?
      @player1.put(x: x, y: y)
    else
      @player2.put(x: x, y: y)
    end
    print_board @board.board, event
  rescue ArgumentError => e
    @bot.send_message(@channel, '既に置いてあります')
    return
  end
  if @judge.mark_align?('o')
    @bot.send_message @channel, 'o win!'
    @is_game_start = false
    init
  elsif @judge.mark_align?('x')
    @bot.send_message @channel, 'x win!'
    @is_game_start = false
    init
  elsif @judge.all_squares_marked?
    @bot.send_message @channel, 'draw'
    @is_game_start = false
    init
  else
    @bot.send_message @channel, '交代して入力して下さい。'
  end
end

@bot.command :play do |event, game_mode, difficulty, order_to_attack|
  @user = event.user.id
  @channel = event.channel.id
  difficulty_text = ''
  game_mode_text = ''
  order_to_attack_text = ''
  @difficulty = 1
  @order_to_attack = 1
  if game_mode == '1'
    @game_mode = game_mode.to_i
    game_mode_text = '二人対戦'
  elsif game_mode == '2'
    @game_mode = game_mode.to_i
    game_mode_text = 'AIと対戦'
  elsif game_mode == '3'
    @game_mode = game_mode.to_i
    game_mode_text = 'AI同士が闘う'
  else
    event.send_message('入力されたゲームモードが不正です。gamemode 1: 2players, 2:single')
    break
  end
  unless @game_mode == 1
    if difficulty == '1'
      @difficulty = difficulty.to_i
      difficulty_text = 'hard'
    elsif difficulty == '2'
      @difficulty = difficulty.to_i
      difficulty_text = 'easy'
    else
      event.send_message('入力された難易度が不正です。1か2で入力して下さい。')
      break
    end
    if order_to_attack == '0'
      @order_to_attack = order_to_attack.to_i
      order_to_attack_text = '先攻です'
    elsif order_to_attack == '1'
      @order_to_attack = order_to_attack.to_i
      order_to_attack_text = '後攻です'
    else
      event.send_message('先攻・後攻は0か1で入力して下さい。0:先攻, 1:後攻')
      break
    end
  end

  @is_game_start = true
  @allow_input = false
  event.send_message("User#{event.user.name}がゲームのプレイを開始しました。")
  event.send_message("ゲームモード：#{game_mode_text}、難易度は#{difficulty_text}、CPUとの戦闘ではプレイヤーは#{order_to_attack_text}")if @game_mode == 2
  event.send_message("ゲームモード：#{game_mode_text}") if @game_mode == 1
  define(game_mode: @game_mode, difficulty: @difficulty, order_to_attack: @order_to_attack)
  event.send_message('o-x!start で開始します。')
  nil
end

@bot.command :start do |event|
  break if @already_started
  break unless @is_game_start
  break unless event.user.id == @user

  @already_started = true
  @allow_input = true
  if @game_mode == 1
    print_board(@board.board, event)
    @bot.send_message @channel,
'置く位置を選んで下さい。
選んだら１〜９を`o-x!put 4`のように入力して下さい。'
  elsif @game_mode == 2
    @is_inputed = false
    p_vs_cpu event
  else
    @bot.send_message @channel, 'mode3は未実装です,初期化します'
    init
  end
  nil
end

@bot.command :stop do |event|
  event.send_message('ゲームを初期化します。')
  @is_inputed = false
  @is_game_start = false
  @already_started = false
  define(game_mode: @game_mode, difficulty: @difficulty, order_to_attack: @order_to_attack)
  nil
end

@bot.command :put do |event, num|
  break unless @is_game_start && @allow_input

  unless num =~ /[1-9]/
    @bot.send_message @channel, '1-9で入力して下さい'
    break
  end

  num = num.to_i

  if num > 3 && num < 7
    x = num - 3 - 1
    y = 1
  elsif num > 6
    x = num - 6 - 1
    y = 2
  else
    x = num - 1
    y = 0
  end

  if @game_mode == 1
    p_vs_p(event, x, y)
    break
  elsif @game_mode == 2
    @is_inputed = true
    p_vs_cpu(event, x, y)
  end
  nil
end

@bot.command :help do |event|
  message = <<-HELP
  まるばつゲームが遊べるBotです。
  コマンド例です

  ```o-x!play game_mode difficulty order_to_attack```
  ゲームモードは１が友達と対戦モード、２がCPUと対戦モードです。
  難易度は1が最強、2がちょっと弱いです。
  Order to attackは攻撃順の意、CPUと対戦する時の先攻か後攻かを決めます。
  0が先攻 1が後攻です
  ```o-x!stop```
  ゲームを中止します。
  HELP

  event.send_message(message)
end

@bot.run
