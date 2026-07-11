defmodule Duel.Game.Matchmaker do
  use GenServer

  require Logger

  alias Duel.Game.Room.Server, as: RoomServer

  @type room_id :: String.t()
  @type player_id :: String.t()

  defstruct waiting_rooms: []

  @type t :: %__MODULE__{
          waiting_rooms: [room_id()]
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec find_or_create_room(player_id(), map()) :: {:ok, room_id()} | {:error, atom()}
  def find_or_create_room(player_id, attrs \\ %{}) do
    GenServer.call(__MODULE__, {:find_or_create_room, player_id, attrs})
  end

  @spec create_room(player_id(), map()) :: {:ok, room_id()} | {:error, atom()}
  def create_room(player_id, attrs \\ %{}) do
    GenServer.call(__MODULE__, {:create_room, player_id, attrs})
  end

  @impl true
  def init(:ok) do
    Logger.info("Matchmaker service started successfully.")
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:find_or_create_room, player_id, attrs}, _from, state) do
    case find_available_room(state.waiting_rooms, player_id, attrs) do
      {:ok, room_id, updated_rooms} ->
        {:reply, {:ok, room_id}, %{state | waiting_rooms: updated_rooms}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:create_room, _player_id, attrs}, _from, state) do
    case create_new_room(Map.put(attrs, :type, :private)) do
      {:ok, room_id} ->
        {:reply, {:ok, room_id}, state}

      {:error, reason} ->
        Logger.error("Failed to create private room: #{inspect(reason)}")
        {:reply, {:error, :room_creation_failed}, state}
    end
  end

  defp find_available_room([], _player_id, attrs) do
    case create_new_room(attrs) do
      {:ok, room_id} ->
        {:ok, room_id, [room_id]}

      {:error, reason} ->
        Logger.error("Matchmaker failed to spin up a new room: #{inspect(reason)}")
        {:error, :room_creation_failed}
    end
  end

  defp find_available_room([room_id | rest] = current_rooms, player_id, attrs) do
    if RoomServer.can_join?(room_id, player_id, attrs) do
      {:ok, room_id, current_rooms}
    else
      case find_available_room(rest, player_id, attrs) do
        {:ok, found_room_id, updated_rest} ->
          {:ok, found_room_id, [room_id | updated_rest]}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp create_new_room(attrs) do
    room_id = generate_room_id()

    case RoomServer.start_room(room_id, attrs) do
      {:ok, _pid} ->
        {:ok, room_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_room_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16()
  end
end
