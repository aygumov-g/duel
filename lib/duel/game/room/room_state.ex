defmodule Duel.Game.Room.State do
  alias Duel.Game.Math.Problem, as: MathProblem

  defstruct room_id: nil,
            players: nil,
            scores: nil,
            current_problem: nil,
            status: nil,
            time_left: nil,
            rematch_votes: nil

  def new(room_id) do
    %__MODULE__{
      room_id: room_id,
      players: [],
      scores: %{},
      current_problem: MathProblem.generate(),
      status: :waiting,
      time_left: 60,
      rematch_votes: []
    }
  end

  def add_player(%__MODULE__{players: players} = state, player_id) do
    if player_id in players do
      state
    else
      new_players = [player_id | players]
      new_scores = Map.put(state.scores, player_id, 0)
      state = %{state | players: new_players, scores: new_scores}

      case new_players do
        [_, _] ->
          %{
            state
            | status: :playing,
              time_left: 60
          }

        _ ->
          state
      end
    end
  end

  def check_answer(%__MODULE__{status: :playing} = state, player_id, answer) do
    if state.current_problem.correct_answer == answer do
      %{
        state
        | scores: Map.update!(state.scores, player_id, &(&1 + 1)),
          current_problem: MathProblem.generate()
      }
    else
      scores =
        Map.update!(state.scores, player_id, fn score ->
          if score > 0 do
            score - 1
          else
            score
          end
        end)

      %{state | scores: scores}
    end
  end

  def check_answer(state, _player_id, _answer) do
    state
  end

  def vote_rematch(%__MODULE__{status: :game_over} = state, player_id) do
    if player_id in state.rematch_votes do
      state
    else
      new_votes = [player_id | state.rematch_votes]
      state = %{state | rematch_votes: new_votes}

      if length(new_votes) == length(state.players) do
        reset_scores = Map.new(state.players, fn p -> {p, 0} end)

        %{
          state
          | status: :playing,
            scores: reset_scores,
            current_problem: MathProblem.generate(),
            time_left: 60,
            rematch_votes: []
        }
      else
        state
      end
    end
  end

  def vote_rematch(state, _player_id), do: state
end
