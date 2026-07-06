defmodule Duel.Game.Matchmaker do
  use GenServer

  alias Duel.Game.Room.Server, as: RoomServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def find_or_create_room(player_id) do
    GenServer.call(__MODULE__, {:find_or_create_room, player_id})
  end

  @impl true
  def init(:ok), do: {:ok, nil}

  @impl true
  def handle_call({:find_or_create_room, _player_id}, _from, nil) do
    room_id = generate_room_id()

    {:ok, _pid} = RoomServer.start_room(room_id)
    {:reply, room_id, room_id}
  end

  @impl true
  def handle_call({:find_or_create_room, player_id}, _from, waiting_room_id) do
    case Registry.lookup(Duel.GameRegistry, waiting_room_id) do
      [] ->
        room_id = generate_room_id()

        {:ok, _pid} = RoomServer.start_room(room_id)
        {:reply, room_id, room_id}

      [_pid] ->
        room_state = RoomServer.get_state(waiting_room_id)

        cond do
          player_id in room_state.players ->
            {:reply, waiting_room_id, waiting_room_id}

          length(room_state.players) < 2 ->
            {:reply, waiting_room_id, nil}

          true ->
            room_id = generate_room_id()

            {:ok, _pid} = RoomServer.start_room(room_id)
            {:reply, room_id, room_id}
        end
    end
  end

  defp generate_room_id() do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16()
  end
end
