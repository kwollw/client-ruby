# frozen_string_literal: true

require_relative './util/constants'
require_relative 'invalid_move_exception'
require_relative 'set_move'

require 'set'

# Methoden, welche die Spielregeln von Blokus abbilden.
#
# Es gibt hier viele Helfermethoden, die von den beiden Hauptmethoden {GameRuleLogic#valid_move?}
# und {GameRuleLogic.possible_moves} benutzt werden.
class GameRuleLogic
  include Constants

  SUM_MAX_SQUARES = 89

  # --- Possible Moves ------------------------------------------------------------

  # Gibt alle möglichen Züge für den Spieler zurück, der in der gamestate dran ist.
  # Diese ist die wichtigste Methode dieser Klasse für Schüler.
  #
  # @param gamestate [GameState] Der zu untersuchende Spielstand.
  def self.possible_moves(gamestate)
    re = possible_setmoves(gamestate)

    re << SkipMove.new unless gamestate.is_first_move?

    re
  end

  # Gibt einen zufälligen möglichen Zug zurück
  # @param gamestate [GameState] Der zu untersuchende Spielstand.
  def self.possible_move(gamestate)
    possible_moves(gamestate).sample
  end

  # Gibt alle möglichen Legezüge zurück
  # @param gamestate [GameState] Der zu untersuchende Spielstand.
  def self.possible_setmoves(gamestate)
    if gamestate.is_first_move?
      possible_start_moves(gamestate)
    else
      all_possible_setmoves(gamestate).flatten
    end
  end

  # Gibt alle möglichen Legezüge in der ersten Runde zurück
  # @param gamestate [GameState] Der zu untersuchende Spielstand.
  def self.possible_start_moves(gamestate)
    color = gamestate.current_color
    shape = gamestate.start_piece
    area1 = shape.dimension
    area2 = Coordinates.new(area1.y, area1.x)
    moves = Set[]

    # Hard code corners for most efficiency (and because a proper algorithm would be pretty illegible here)
    # Upper Left
    moves.merge(moves_for_shape_on(color, shape, Coordinates.new(0, 0)))

    # Upper Right
    moves.merge(moves_for_shape_on(color, shape, Coordinates.new(BOARD_SIZE - area1.x, 0)))
    moves.merge(moves_for_shape_on(color, shape, Coordinates.new(BOARD_SIZE - area2.x, 0)))

    # Lower Left
    moves.merge(moves_for_shape_on(color, shape, Coordinates.new(0, BOARD_SIZE - area1.y)))
    moves.merge(moves_for_shape_on(color, shape, Coordinates.new(0, BOARD_SIZE - area2.y)))

    # Lower Right
    moves.merge(moves_for_shape_on(color, shape, Coordinates.new(BOARD_SIZE - area1.x, BOARD_SIZE - area1.y)))
    moves.merge(moves_for_shape_on(color, shape, Coordinates.new(BOARD_SIZE - area2.x, BOARD_SIZE - area2.y)))

    moves.select { |m| valid_set_move?(gamestate, m) }.to_a
  end

  # Hilfsmethode um Legezüge für eine [PieceShape] zu berechnen.
  # @param color [Color] Die Farbe der Spielsteine der Züge
  # @param shape [PieceShape] Die Form der Spielsteine der Züge
  # @param position [Coordinates] Die Position der Spielsteine der Züge
  def self.moves_for_shape_on(color, shape, position)
    moves = Set[]
    Rotation.each do |r|
      [true, false].each do |f|
        moves << SetMove.new(Piece.new(color, shape, r, f, position))
      end
    end
    moves
  end

  # Gib eine Liste aller möglichen Legezüge zurück, auch wenn es die erste Runde ist.
  # @param gamestate [GameState] Der zu untersuchende Spielstand.
  def self.all_possible_setmoves(gamestate)
    moves = []
    fields = valid_fields(gamestate)
    gamestate.undeployed_pieces(gamestate.current_color).each do |p|
      (moves << possible_moves_for_shape(gamestate, p, fields)).flatten
    end
    moves
  end

  # Gibt eine Liste aller möglichen SetMoves für diese Form zurück.
  # @param gamestate [GameState] Der zu untersuchende Spielstand.
  # @param shape Die [PieceShape], die die Züge nutzen sollen
  #
  # @return Alle möglichen Züge mit der Form
  def self.possible_moves_for_shape(gamestate, shape, fields = valid_fields(gamestate))
    color = gamestate.current_color

    moves = Set[]
    fields.each do |field|
      shape.unique_transforms().each do |t|
        piece = Piece.new(color, shape, t.r, t.f, Coordinates.new(0, 0))
        piece.coords.each do |pos|
          moves << SetMove.new(Piece.new(color, shape, t.r, t.f, Coordinates.new(field.x - pos.x, field.y - pos.y)))
        end
      end
    end
    moves.select { |m| valid_set_move?(gamestate, m) }.to_a
  end

  # Gibt eine Liste aller Felder zurück, an denen möglicherweise Züge gemacht werden kann.
  # @param gamestate [GameState] Der zu untersuchende Spielstand.
  def self.valid_fields(gamestate)
    color = gamestate.current_color
    board = gamestate.board
    fields = Set[]
    board.fields_of_color(color).each do |field|
      [Coordinates.new(field.x - 1, field.y - 1),
       Coordinates.new(field.x - 1, field.y + 1),
       Coordinates.new(field.x + 1, field.y - 1),
       Coordinates.new(field.x + 1, field.y + 1)].each do |corner|
        next unless Board.contains(corner)
        next unless board[corner].empty?
        next if neighbor_of_color?(board, Field.new(corner.x, corner.y), color)

        fields << corner
      end
    end
    fields
  end

  # Überprüft, ob das gegebene Feld ein Nachbarfeld mit der Farbe [color] hat
  # @param board [Board] Das aktuelle Board
  # @param field [Field] Das zu überprüfende Feld
  # @param color [Color] Nach der zu suchenden Farbe
  def self.neighbor_of_color?(board, field, color)
    [Coordinates.new(field.x - 1, field.y),
     Coordinates.new(field.x, field.y - 1),
     Coordinates.new(field.x + 1, field.y),
     Coordinates.new(field.x, field.y + 1)].any? do |neighbor|
      Board.contains(neighbor) && board[neighbor].color == color
    end
  end

  # # Return a list of all moves, impossible or not.
  # # There's no real usage, except maybe for cases where no Move validation happens
  # # if `Constants.VALIDATE_MOVE` is false, then this function should return the same
  # # Set as `::getPossibleMoves`
  # def self.get_all_set_moves()
  #   moves = []
  #   Color.each do |c|
  #     PieceShape.each do |s|
  #       Rotation.each do |r|
  #         [false, true].each do |f|
  #           (0..BOARD_SIZE-1).to_a.each do |x|
  #             (0..BOARD_SIZE-1).to_a.each do |y|
  #               moves << SetMove.new(Piece.new(c, s, r, f, Coordinates.new(x, y)))
  #             end
  #           end
  #         end
  #       end
  #     end
  #   end
  #   moves
  # end

  # --- Move Validation ------------------------------------------------------------

  # Prüft, ob der gegebene [Move] zulässig ist.
  # @param gamestate [GameState] Der zu untersuchende Spielstand.
  # @param move der zu überprüfende Zug
  #
  # @return ob der Zug zulässig ist
  def self.valid_move?(gamestate, move)
    if move.instance_of? SkipMove
      !gamestate.is_first_move?
    else
      valid_set_move?(gamestate, move)
    end
  end

  # Prüft, ob der gegebene [SetMove] zulässig ist.
  # @param gamestate [GameState] der aktuelle Spielstand
  # @param move [SetMove] der zu überprüfende Zug
  #
  # @return ob der Zug zulässig ist
  def self.valid_set_move?(gamestate, move)
    return false if move.piece.color != gamestate.current_color

    if gamestate.is_first_move?
      # on first turn, only the start piece is allowed
      return false if move.piece.kind != gamestate.start_piece
      # and it may only be placed in a corner
      return false if move.piece.coords.none? { |it| corner?(it) }
    else
      # in all other turns, only unused pieces may be placed
      return false unless gamestate.undeployed_pieces(move.piece.color).include?(move.piece.kind)
      # and it needs to be connected to another piece of the same color
      return false if move.piece.coords.none? { |it| corners_on_color?(gamestate.board, it, move.piece.color) }
    end

    # all parts of the piece need to be
    move.piece.coords.each do |it|
      # - on the board
      return false unless gamestate.board.in_bounds?(it)
      # - on a empty field
      return false if obstructed?(gamestate.board, it)
      # - not next to a field occupied by the same color
      return false if borders_on_color?(gamestate.board, it, move.piece.color)
    end

    true
  end

  # Überprüft, ob das gegebene Feld ein Nachbarfeld mit der Farbe [color] hat
  # @param board [Board] Das aktuelle Spielbrett
  # @param field [Field] Das zu überprüfende Feld
  # @param color [Color] Nach der zu suchenden Farbe
  def self.borders_on_color?(board, position, color)
    [Coordinates.new(1, 0), Coordinates.new(0, 1), Coordinates.new(-1, 0), Coordinates.new(0, -1)].any? do |it|
      if board.in_bounds?(position + it)
        board[position + it].color == color
      else
        false
      end
    end
  end

  # Überprüft, ob das gegebene Feld ein diagonales Nachbarfeld mit der Farbe [color] hat
  # @param board [Board] Das aktuelle Spielbrett
  # @param position [Field] Das zu überprüfende Feld
  # @param color [Color] Nach der zu suchenden Farbe
  def self.corners_on_color?(board, position, color)
    [Coordinates.new(1, 1), Coordinates.new(1, -1), Coordinates.new(-1, -1), Coordinates.new(-1, 1)].any? do |it|
      board.in_bounds?(position + it) && board[position + it].color == color
    end
  end

  # Überprüft, ob die gegebene [position] an einer Ecke des Boards liegt.
  # @param position [Coordinates] Die zu überprüfenden Koordinaten
  def self.corner?(position)
    corner = [
      Coordinates.new(0, 0),
      Coordinates.new(BOARD_SIZE - 1, 0),
      Coordinates.new(0, BOARD_SIZE - 1),
      Coordinates.new(BOARD_SIZE - 1, BOARD_SIZE - 1)
    ]
    corner.include? position
  end

  # Überprüft, ob die gegebene [position] schon mit einer Farbe belegt wurde.
  # @param board [Board] Das aktuelle Spielbrett
  # @param position [Coordinates] Die zu überprüfenden Koordinaten
  def self.obstructed?(board, position)
    !board[position].color.nil?
  end

  # --- Perform Move ------------------------------------------------------------

  # Führe den gegebenen [Move] im gebenenen [GameState] aus.
  # @param gamestate [GameState] der aktuelle Spielstand
  # @param move der auszuführende Zug
  def self.perform_move(gamestate, move)
    raise 'Invalid move!' unless valid_move?(gamestate, move)

    if move.instance_of? SetMove
      gamestate.undeployed_pieces(move.piece.color).delete(move.piece)

      # Apply piece to board
      move.piece.coords.each do |coord|
        gamestate.board[coord].color = move.piece.color
      end

      # If it was the last piece for this color, remove it from the turn queue
      if gamestate.undeployed_pieces(move.piece.color).empty?
        gamestate.lastMoveMono += move.color to(move.piece.kind == PieceShape.MONO)
        gamestate.remove_active_color
      end
    end
    gamestate.turn += 1
    gamestate.round += 1
    gamestate.last_move = move
  end

  # --- Other ------------------------------------------------------------

  # Berechne den Punktestand anhand der gegebenen [PieceShape]s.
  # @param undeployed eine Sammlung aller nicht gelegten [PieceShape]s
  # @param monoLast ob der letzte gelegte Stein das Monomino war
  #
  # @return die erreichte Punktezahl
  def self.get_points_from_undeployed(undeployed, mono_last = false)
    # If all pieces were placed:
    if undeployed.empty?
      # Return sum of all squares plus 15 bonus points
      return SUM_MAX_SQUARES + 15 +
             # If the Monomino was the last placed piece, add another 5 points
             mono_last ? 5 : 0
    end
    # One point per block per piece placed
    SUM_MAX_SQUARES - undeployed.map(&:size).sum
  end

  # Gibt einen zufälligen Pentomino zurück, welcher nicht `x` ist.
  def self.get_random_pentomino
    PieceShape.map(&:value).select { |it| it.size == 5 && it != PieceShape::PENTO_X }
  end

  # Entferne alle Farben, die keine Steine mehr auf dem Feld platzieren können.
  def remove_invalid_colors(gamestate)
    return if gamestate.ordered_colors.empty?
    return unless get_possible_moves(gamestate).empty?

    gamestate.remove_active_color
    remove_invalid_colors(gamestate)
  end

  # Prueft, ob ein Spieler im gegebenen GameState gewonnen hat.
  # @param gamestate [GameState] Der zu untersuchende GameState.
  # @return [Condition] nil, if the game is not won or a Condition indicating the winning player
  def self.winning_condition(_gamestate)
    raise 'Not implemented yet!'
  end
end
