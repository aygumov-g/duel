defmodule DuelWeb.PageController do
  use DuelWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
