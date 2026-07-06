defmodule DuelWeb.RoomController do
  use DuelWeb, :controller

  def index(conn, _params) do
    # Достаем player_id, который сгенерировал наш Plug
    player_id = get_session(conn, :player_id)

    # Передаем его в обновленный матчмейкер
    room_id = Duel.Game.Matchmaker.find_or_create_room(player_id)

    redirect(conn, to: "/room/#{room_id}")
  end
end
