defmodule Duel.Game.Room.State do
  alias Duel.Game.Math.Problem, as: MathProblem

  defstruct [
    :room_id,
    :current_problem,
    :type,
    :status,
    :players,
    :max_players,
    :rematch_votes,
    :duration,
    :time_left
  ]

  @type type :: :public | :private
  @type status :: :waiting | :playing | :game_over
  @type player :: %{score: non_neg_integer()}

  @type t :: %__MODULE__{
          room_id: String.t(),
          status: status(),
          type: type(),
          players: %{String.t() => player()},
          max_players: pos_integer(),
          rematch_votes: MapSet.t(String.t()),
          current_problem: MathProblem.t() | nil,
          duration: pos_integer(),
          time_left: non_neg_integer()
        }

  @spec new(String.t()) :: t()
  @spec new(String.t(), map()) :: t()
  def new(room_id, attrs \\ %{}) do
    %__MODULE__{
      room_id: room_id,
      type: Map.get(attrs, :type, :public),
      status: :waiting,
      players: %{},
      duration: Map.get(attrs, :duration, 60),
      time_left: Map.get(attrs, :duration, 60),
      max_players: Map.get(attrs, :max_players, 2),
      rematch_votes: MapSet.new(),
      current_problem: MathProblem.generate()
    }
  end

  @spec tick(t()) :: t()
  def tick(%__MODULE__{status: :playing} = state) do
    if state.time_left > 0 do
      %{state | time_left: state.time_left - 1}
    else
      %{state | status: :game_over}
    end
  end

  def tick(state) do
    state
  end

  @spec add_player(t(), String.t()) :: t()
  def add_player(%__MODULE__{status: :waiting} = state, player_id) do
    if Map.has_key?(state.players, player_id) do
      state
    else
      new_players = Map.put(state.players, player_id, %{score: 0})

      if map_size(new_players) == state.max_players do
        %{state | players: new_players, status: :playing}
      else
        %{state | players: new_players}
      end
    end
  end

  def add_player(state, _player_id) do
    state
  end

  @spec vote_rematch(t(), String.t()) :: t()
  def vote_rematch(%__MODULE__{status: :game_over} = state, player_id) do
    if Map.has_key?(state.players, player_id) do
      new_votes = MapSet.put(state.rematch_votes, player_id)

      if MapSet.size(new_votes) == map_size(state.players) do
        reset_players = Map.new(state.players, fn {id, _data} -> {id, %{score: 0}} end)

        %{
          state
          | status: :playing,
            players: reset_players,
            rematch_votes: MapSet.new(),
            current_problem: MathProblem.generate(),
            time_left: state.duration
        }
      else
        %{state | rematch_votes: new_votes}
      end
    else
      state
    end
  end

  def vote_rematch(state, _player_id) do
    state
  end

  @spec check_answer(t(), String.t(), any()) :: t()
  def check_answer(%__MODULE__{status: :playing} = state, player_id, answer) do
    if Map.has_key?(state.players, player_id) do
      if state.current_problem.correct_answer == answer do
        update_score(state, player_id, 1, true)
      else
        update_score(state, player_id, -1, false)
      end
    else
      state
    end
  end

  def check_answer(state, _player_id, _answer) do
    state
  end

  defp update_score(state, player_id, delta, correct?) do
    new_players =
      Map.update!(state.players, player_id, fn player ->
        %{player | score: max(0, player.score + delta)}
      end)

    if correct? do
      %{state | players: new_players, current_problem: MathProblem.generate()}
    else
      %{state | players: new_players}
    end
  end
end
