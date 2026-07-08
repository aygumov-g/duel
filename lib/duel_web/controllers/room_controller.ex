defmodule DuelWeb.RoomController do
  use DuelWeb, :controller

  def index(conn, _params) do
    get_session(conn, :player_id)
    |> Duel.Game.Matchmaker.find_or_create_room()
    |> case do
      {:ok, room_id} ->
        redirect(conn, to: "/room/#{room_id}")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Не удалось создать комнату")
        |> redirect(to: "/")
    end
  end
end
