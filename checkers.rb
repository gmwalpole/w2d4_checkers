require 'colorize'

class Checkers

  attr_accessor :board, :players

  def initialize
    @board = Board.new
    @players = [Player.new("Harry"), Player.new("Henderson")]
  end

  def play

    cur_player = players[0]
    until check_win
      board.render
      move = cur_player.get_input
      parse_and_execute(move)

      cur_player == (players[0] ? players[1] : players[0])
    end

    winner == (check_win == :red ? "Red" : "Black")
    puts "#{winner} is the winner!"
  end

  def check_win
    return :black if board.get_all_pieces(:red).empty?
    return :red if board.get_all_pieces(:black).empty?
    false
  end

  def parse_and_execute(move_string)

  end

end

class Player
  attr_accessor :name

  def initialize(name)
    @name = name
  end

  def get_input
    puts "Enter start and end coordinates: (Ex: '1A,2B')"
    gets
  end

end

class Board
  BOARD_SIZE = 8

  attr_accessor :grid

  def initialize(init_empty = false)

    @grid = Array.new(BOARD_SIZE) { Array.new(BOARD_SIZE) }
    set_starting_positions unless init_empty

  end

  def set_starting_positions
    grid.each_with_index do |row, row_index|
      color_to_place = (row_index < 3 ? :red : :black)
      color_to_place = nil if (row_index >= 3 && row_index < 5)
      row.each_with_index do |col, col_index|
        if (row_index + col_index) % 2 == 1
          put_piece(color_to_place,[row_index, col_index]) if color_to_place
        end
      end
    end
  end

  def put_piece(color, pos, is_king = false)
    row, col = pos
    @grid[row][col] = Piece.new(color, pos, self, is_king)
  end

  def inspect
    #render
    nil
  end

  def color_square(row, col)
    bg_color = (row + col) % 2 == 0 ? :light_red : :light_black
    cur_piece = grid[row][col]
    square_string = (cur_piece ? "#{cur_piece.symbol} " : "  ")
    p_color = cur_piece.color if cur_piece
    square_string.colorize( :color => p_color, :background => bg_color )
  end

  def render
    puts "_|A B C D E F G H "
    grid.each_with_index do |row, row_index|
      row_string = "#{row_index}|"
      row.each_with_index do |col, col_index|
        row_string += color_square(row_index, col_index)
      end
      puts row_string + ""
    end
    nil
  end

  def is_piece_at? (pos,color = nil)
    row, col = pos
    piece = grid[row][col]
    if color == nil
      piece ? true : false
    else
      piece && piece.color == color ? true : false
    end
  end

  def in_bounds?(pos)
    return true if (pos[0] >= 0 && pos[0] < BOARD_SIZE &&
    pos[1] >= 0 && pos[1] < BOARD_SIZE)
    false
  end

  def get_all_pieces(color = nil)
    return grid.flatten.compact unless color
    grid.flatten.compact.select { |i| i.color == color }
  end

  def dup
    test_board = Board.new(true)
    get_all_pieces.each do |piece|
      test_board.put_piece(piece.color, piece.position, piece.is_king)
    end
    test_board
  end

end

class Piece

  DIAGS = [[-1, -1],[1, -1],
           [-1, 1], [1, 1]]

  attr_accessor :is_king, :color, :symbol, :position, :board

  def initialize(color, position, board, kingliness = false)
    @color = color
    @position = position
    @board = board
    @symbol = "\u2B24" #(color == :red ? "r" : "b")
    promote if kingliness #used when copying board
  end

  def promote
    @is_king = true
    @symbol = "\u265A" #(color == :red ? "R" : "B")
  end

  def forward
    color == :red ? 1 : -1
  end

  def opposing_color
    color == :red ? :black : :red
  end

  def move_diffs
    moves = DIAGS
    moves = moves.select { |i| i[0] == forward } unless is_king
    moves
  end

  def perform_slide(pos, start_pos = position)
    if valid_slide?(pos, start_pos)
      #put a copy of self at end point
      perform_move(pos, start_pos)
      return true
    end
    false
  end

  def perform_jump(pos, start_pos = position)
    if valid_jump?(pos, start_pos)
      perform_move(pos, start_pos)
      #remove the jumped piece
      row, col = get_jumped_pos(pos, start_pos)
      board.grid[row][col] = nil

      return true
    end
    false
  end

  def perform_move(pos, start_pos)
    #put a copy of self at end point
    @position = pos
    row, col = pos
    board.grid[row][col] = self

    #remove self from starting point
    row, col = start_pos
    board.grid[row][col] = nil

    maybe_promote #check for promotion
  end

  def get_jumped_pos(pos, start_pos)
    row = (start_pos[0] + pos[0]) /2
    col = (start_pos[1] + pos[1]) /2
    [row, col]
  end

  def pos_map(deltas, pos)
    deltas.map { |i| [i[0] + pos[0], i[1] + pos[1]]}
  end

  def valid_move?(end_pos, start_pos, is_jump)
    valid_moves = get_valid_moves(is_jump, start_pos)
    valid_moves.include?(end_pos)
  end

  def get_valid_moves(is_jump, start_pos = position)
    valid_moves = pos_map(move_diffs, start_pos)
    valid_moves = adjust_for_jumps(start_pos) if is_jump
    # Yes, we have to do this check twice if we're jumping if
    # we want to keep the jump code in a single method. -_-
    valid_moves.select! { |i| board.in_bounds?(i)}
    valid_moves.select! { |i| !(board.is_piece_at?(i))}
    valid_moves
  end

  def adjust_for_jumps(start_pos)
    jumps = move_diffs.map { |i| [i[0] * 2, i[1] * 2]}
    valid_moves = pos_map(jumps, start_pos)
    valid_moves.select! { |i| board.in_bounds?(i)}
    valid_moves.select! { |i| board.is_piece_at?(get_jumped_pos(i, start_pos), opposing_color)}
    valid_moves
  end

  def valid_slide?(end_pos, start_pos = position)
    valid_move?(end_pos, start_pos, false)
  end

  def valid_jump?(end_pos, start_pos = position)
    valid_move?(end_pos, start_pos, true)
  end

  def perform_moves!(move_sequence)
    prev_pos = position
    move_result = false
    move_result = perform_slide(move_sequence[0]) if move_sequence.length == 1
    unless move_result
      move_result = true
      move_sequence.each do |next_pos|
      move_result = perform_jump(next_pos, prev_pos)
      unless move_result
        raise "Move to #{next_pos} from #{prev_pos} is invalid."
      end
      prev_pos = next_pos
      end
    end
    move_result
  end

  def perform_moves(move_sequence)
    if valid_move_seq?(move_sequence)
      perform_moves!(move_sequence)
    else
      raise "Move sequence is invalid."
    end
  end

  def valid_move_seq?(move_sequence)
    begin
      test_board = board.dup
      row, col = position
      #The piece's shadow clone should be the one attempting this.
      is_valid = test_board.grid[row][col].perform_moves!(move_sequence)
    rescue RuntimeError => e
      puts e.message
      return false
    end
    is_valid
  end

  def maybe_promote
    promote if (color == :red && position[0] == (BOARD_SIZE - 1) ||
                color == :black && position[0] == 0)
  end

end
