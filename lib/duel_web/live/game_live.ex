defmodule DuelWeb.GameLive do
  use DuelWeb, :live_view

  require Logger

  alias Duel.Game.Room.Server, as: RoomServer

  @impl true
  def mount(%{"id" => room_id}, session, socket) do
    if room_alive?(room_id) do
      mount_room(socket, room_id, session["player_id"])
    else
      {:ok,
       socket
       |> put_flash(:error, "Игра не найдена или уже завершилась.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("answer", %{"ans" => answer_str}, socket) do
    case Integer.parse(answer_str) do
      {answer, ""} ->
        RoomServer.check_answer(socket.assigns.room_id, socket.assigns.player_id, answer)

      _ ->
        Logger.warning("Player #{socket.assigns.player_id} sent invalid answer: #{answer_str}")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("vote_rematch", _params, socket) do
    RoomServer.vote_rematch(socket.assigns.room_id, socket.assigns.player_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("leave_room", _params, socket) do
    RoomServer.leave(socket.assigns.room_id, socket.assigns.player_id)

    {:noreply,
     socket
     |> put_flash(:info, "Поиск игры отменен.")
     |> redirect(to: ~p"/")}
  end

  @impl true
  def handle_info({:room_updated, new_state}, socket) do
    {:noreply, assign(socket, :game_state, new_state)}
  end

  defp mount_room(socket, room_id, player_id) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Duel.PubSub, "room:#{room_id}")

      case RoomServer.join(room_id, player_id) do
        :ok ->
          {:ok,
           assign(socket,
             room_id: room_id,
             player_id: player_id,
             game_state: RoomServer.get_state(room_id)
           )}

        {:error, _reason} ->
          {:ok,
           socket
           |> put_flash(:error, "Не удалось присоединиться к игре.")
           |> redirect(to: ~p"/")}
      end
    else
      {:ok,
       assign(socket,
         room_id: room_id,
         player_id: player_id,
         game_state: RoomServer.get_state(room_id)
       )}
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

  defp generate_qr_svg(url) do
    url
    |> EQRCode.encode()
    |> EQRCode.svg(
      color: "#000000",
      shape_design: :default,
      width: 160
    )
  end
end
