defmodule DuelWeb.Plugs.PlayerId do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :player_id) do
      conn
    else
      put_session(conn, :player_id, "player_#{:crypto.strong_rand_bytes(4) |> Base.encode16()}")
    end
  end
end
