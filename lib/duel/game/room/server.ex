defmodule Duel.Game.Room.Server do
  use GenServer, restart: :temporary

  require Logger

  alias Duel.Game.Room.State, as: RoomState

  @empty_room_timeout :timer.minutes(5)
  @game_over_timeout :timer.minutes(2)

  @spec start_room(String.t()) :: DynamicSupervisor.on_start_child()
  @spec start_room(String.t(), map()) :: DynamicSupervisor.on_start_child()
  def start_room(room_id, attrs \\ %{}) do
    DynamicSupervisor.start_child(Duel.GameSupervisor, {__MODULE__, {room_id, attrs}})
  end

  @spec start_link(%{room_id: String.t(), attrs: map()}) :: GenServer.on_start()
  def start_link({room_id, attrs}) do
    GenServer.start_link(__MODULE__, {room_id, attrs}, name: via_tuple(room_id))
  end

  @spec get_state(String.t()) :: RoomState.t()
  def get_state(room_id) do
    GenServer.call(via_tuple(room_id), :get_state)
  end

  @spec join(String.t(), String.t()) :: :ok | {:error, atom()}
  def join(room_id, player_id) do
    GenServer.call(via_tuple(room_id), {:join, player_id})
  end

  @spec vote_rematch(String.t(), String.t()) :: :ok | {:error, atom()}
  def vote_rematch(room_id, player_id) do
    GenServer.call(via_tuple(room_id), {:vote_rematch, player_id})
  end

  @spec check_answer(String.t(), String.t(), any()) :: :ok | {:error, atom()}
  def check_answer(room_id, player_id, answer) do
    GenServer.call(via_tuple(room_id), {:check_answer, player_id, answer})
  end

  @spec can_join?(String.t(), String.t(), map()) :: boolean()
  def can_join?(room_id, player_id, attrs) do
    case Registry.lookup(Duel.GameRegistry, room_id) do
      [{pid, _value}] ->
        GenServer.call(pid, {:can_join?, player_id, attrs})

      [] ->
        false
    end
  end

  @spec leave(String.t(), String.t()) :: :ok
  def leave(room_id, player_id) do
    GenServer.cast(via_tuple(room_id), {:leave, player_id})
  end

  @impl true
  def init({room_id, attrs}) do
    Logger.info("Creating game room: #{room_id}")
    {:ok, RoomState.new(room_id, attrs), @empty_room_timeout}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state, next_timeout(state)}
  end

  @impl true
  def handle_call({:join, player_id}, _from, state) do
    if Map.has_key?(state.players, player_id) do
      {:reply, :ok, state, next_timeout(state)}
    else
      case RoomState.add_player(state, player_id) do
        ^state ->
          {:reply, {:error, :cannot_join}, state, next_timeout(state)}

        new_state ->
          Logger.info("Player #{player_id} joined room #{state.room_id}")

          if state.status == :waiting and new_state.status == :playing do
            Logger.info("Match started in room #{state.room_id}")
            schedule_tick()
          end

          broadcast_state(new_state)
          {:reply, :ok, new_state, next_timeout(new_state)}
      end
    end
  end

  @impl true
  def handle_call({:vote_rematch, player_id}, _from, state) do
    case RoomState.vote_rematch(state, player_id) do
      ^state ->
        {:reply, {:error, :cannot_vote}, state, next_timeout(state)}

      new_state ->
        if state.status == :game_over and new_state.status == :playing do
          Logger.info("Rematch accepted in room #{state.room_id}")
          schedule_tick()
        end

        broadcast_state(new_state)
        {:reply, :ok, new_state, next_timeout(new_state)}
    end
  end

  @impl true
  def handle_call({:check_answer, player_id, answer}, _from, state) do
    case RoomState.check_answer(state, player_id, answer) do
      ^state ->
        {:reply, {:error, :invalid_action}, state, next_timeout(state)}

      new_state ->
        broadcast_state(new_state)
        {:reply, :ok, new_state, next_timeout(new_state)}
    end
  end

  @impl true
  def handle_call({:can_join?, player_id, attrs}, _from, state) do
    attrs_match? =
      Enum.all?(attrs, fn {key, value} ->
        Map.get(state, key) == value
      end)

    can? =
      attrs_match? and
        (Map.has_key?(state.players, player_id) or
           (state.status == :waiting and
              map_size(state.players) < state.max_players))

    IO.puts("attrs_match?=#{attrs_match?} can?=#{can?}")
    IO.inspect(attrs)
    IO.inspect(state)

    {:reply, can?, state}
  end

  @impl true
  def handle_cast({:leave, player_id}, state) do
    if state.status in [:waiting, :game_over] and Map.has_key?(state.players, player_id) do
      new_players = Map.delete(state.players, player_id)

      if map_size(new_players) == 0 do
        Logger.info("Room empty. Shutting down room #{state.room_id}.")
        {:stop, :normal, state}
      else
        Logger.info("Player #{player_id} left. Room #{state.room_id} still alive.")
        new_state = %{state | players: new_players}
        broadcast_state(new_state)
        {:noreply, new_state, next_timeout(new_state)}
      end
    else
      {:noreply, state, next_timeout(state)}
    end
  end

  @impl true
  def handle_info(:tick, %{status: :playing} = state) do
    new_state = RoomState.tick(state)
    broadcast_state(new_state)

    if new_state.status == :playing do
      schedule_tick()
    end

    {:noreply, new_state, next_timeout(new_state)}
  end

  @impl true
  def handle_info(:tick, state) do
    {:noreply, state, next_timeout(state)}
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.info("Closing room #{state.room_id} due to inactivity (status: #{state.status}).")
    {:stop, :normal, state}
  end

  defp next_timeout(%{status: :waiting}), do: @empty_room_timeout
  defp next_timeout(%{status: :game_over}), do: @game_over_timeout
  defp next_timeout(%{status: :playing}), do: :infinity

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
