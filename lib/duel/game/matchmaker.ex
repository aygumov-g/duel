defmodule Duel.Game.Matchmaker do
  use GenServer

  require Logger

  alias Duel.Game.Room.Server, as: RoomServer

  @type room_id :: String.t()
  @type player_id :: String.t()

  defstruct [
    # nil | {room_id(), player_id()}
    waiting_room: nil
  ]

  @type t :: %__MODULE__{
          waiting_room: nil | {room_id(), player_id()}
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec find_or_create_room(player_id()) :: {:ok, room_id()} | {:error, atom()}
  def find_or_create_room(player_id) do
    GenServer.call(__MODULE__, {:find_or_create_room, player_id})
  end

  @impl true
  def init(:ok) do
    Logger.info("Matchmaker service started successfully")
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(
        {:find_or_create_room, player_id},
        _from,
        %__MODULE__{waiting_room: nil} = state
      ) do
    case create_new_room() do
      {:ok, room_id} ->
        new_state = %{state | waiting_room: {room_id, player_id}}
        {:reply, {:ok, room_id}, new_state}

      {:error, reason} ->
        Logger.error("Matchmaker failed to spin up a new room: #{inspect(reason)}")
        {:reply, {:error, :room_creation_failed}, state}
    end
  end

  @impl true
  def handle_call(
        {:find_or_create_room, player_id},
        _from,
        %__MODULE__{waiting_room: {room_id, player_id}} = state
      ) do
    {:reply, {:ok, room_id}, state}
  end

  @impl true
  def handle_call(
        {:find_or_create_room, player_id},
        _from,
        %__MODULE__{waiting_room: {room_id, _old_player_id}} = state
      ) do
    if room_alive?(room_id) do
      {:reply, {:ok, room_id}, %{state | waiting_room: nil}}
    else
      Logger.warning("Matchmaker found a dead room #{room_id} in queue. Creating a fresh one...")

      case create_new_room() do
        {:ok, new_room_id} ->
          new_state = %{state | waiting_room: {new_room_id, player_id}}
          {:reply, {:ok, new_room_id}, new_state}

        {:error, reason} ->
          Logger.error("Matchmaker failed to recreate room: #{inspect(reason)}")
          {:reply, {:error, :room_creation_failed}, %{state | waiting_room: nil}}
      end
    end
  end

  defp create_new_room do
    room_id = generate_room_id()

    case RoomServer.start_room(room_id) do
      {:ok, _pid} ->
        {:ok, room_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp room_alive?(room_id) do
    case Registry.lookup(Duel.GameRegistry, room_id) do
      [{_pid, _value}] ->
        true

      [] ->
        false
    end
  end

  defp generate_room_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16()
  end
end
