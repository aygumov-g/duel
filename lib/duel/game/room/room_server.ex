defmodule Duel.Game.Room.Server do
  use GenServer, restart: :temporary

  alias Duel.Game.Room.State, as: RoomState

  def start_room(room_id) do
    DynamicSupervisor.start_child(Duel.GameSupervisor, {__MODULE__, room_id})
  end

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: via_tuple(room_id))
  end

  def get_state(room_id) do
    GenServer.call(via_tuple(room_id), :get_state)
  end

  def join(room_id, player_id) do
    GenServer.call(via_tuple(room_id), {:join, player_id})
  end

  def check_answer(room_id, player_id, answer) do
    GenServer.call(via_tuple(room_id), {:check_answer, player_id, answer})
  end

  def vote_rematch(room_id, player_id) do
    GenServer.call(via_tuple(room_id), {:vote_rematch, player_id})
  end

  @impl true
  def init(room_id) do
    {:ok, RoomState.new(room_id)}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:join, player_id}, _from, state) do
    new_state = RoomState.add_player(state, player_id)

    if state.status == :waiting and new_state.status == :playing do
      schedule_tick()
    end

    broadcast_state(new_state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:check_answer, player_id, answer}, _from, state) do
    new_state = RoomState.check_answer(state, player_id, answer)

    if new_state != state do
      broadcast_state(new_state)
    end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:vote_rematch, player_id}, _from, state) do
    new_state = RoomState.vote_rematch(state, player_id)

    if state.status == :game_over and new_state.status == :playing do
      schedule_tick()
    end

    broadcast_state(new_state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:tick, %RoomState{status: :playing, time_left: time_left} = state) do
    if time_left > 1 do
      new_state = %{
        state
        | time_left: time_left - 1
      }

      schedule_tick()
      broadcast_state(new_state)

      {:noreply, new_state}
    else
      new_state = %{
        state
        | time_left: 0,
          status: :game_over
      }

      broadcast_state(new_state)

      {:noreply, new_state}
    end
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, 1000)
  end

  defp broadcast_state(state) do
    Phoenix.PubSub.broadcast(Duel.PubSub, "room:#{state.room_id}", {:room_updated, state})
  end

  defp via_tuple(room_id) do
    {:via, Registry, {Duel.GameRegistry, room_id}}
  end
end
