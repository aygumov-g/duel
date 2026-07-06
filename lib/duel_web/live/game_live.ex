defmodule DuelWeb.GameLive do
  use DuelWeb, :live_view

  alias Duel.Game.Room.Server, as: RoomServer

  def mount(%{"id" => room_id}, session, socket) do
    player_id = session["player_id"]

    case Registry.lookup(Duel.GameRegistry, room_id) do
      [] ->
        {:ok,
         socket
         |> put_flash(:error, "Игра не найдена или уже завершилась.")
         |> redirect(to: "/")}

      [_tuple] ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Duel.PubSub, "room:#{room_id}")
          RoomServer.join(room_id, player_id)
        end

        state = RoomServer.get_state(room_id)

        {:ok,
         socket
         |> assign(
           room_id: room_id,
           player_id: player_id,
           game_state: state
         )}
    end
  end

  def handle_event("answer", %{"ans" => answer_str}, socket) do
    answer = String.to_integer(answer_str)

    RoomServer.check_answer(socket.assigns.room_id, socket.assigns.player_id, answer)
    {:noreply, socket}
  end

  def handle_event("vote_rematch", _, socket) do
    RoomServer.vote_rematch(socket.assigns.room_id, socket.assigns.player_id)
    {:noreply, socket}
  end

  def handle_info({:room_updated, new_state}, socket) do
    {:noreply, assign(socket, :game_state, new_state)}
  end
end
