defmodule DuelWeb.IndexLive do
  use DuelWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:player_id, session["player_id"])
     |> assign(:duration, 60)
     |> assign(:max_players, 2)}
  end

  @impl true
  def handle_event("validate", %{"duration" => duration, "max_players" => max_players}, socket) do
    {:noreply,
     socket
     |> assign(:duration, parse_int(duration, 60))
     |> assign(:max_players, parse_int(max_players, 2))}
  end

  @impl true
  def handle_event(
        "handle_game",
        %{"action" => "f", "duration" => d, "max_players" => mp},
        socket
      ) do
    attrs =
      %{
        duration: parse_int(d, 60),
        max_players: parse_int(mp, 2)
      }

    socket.assigns.player_id
    |> Duel.Game.Matchmaker.find_or_create_room(attrs)
    |> case do
      {:ok, room_id} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ищем соперников для дуэли...")
         |> push_navigate(to: ~p"/room/#{room_id}")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Не удалось обработать запрос комнаты.")}
    end
  end

  @impl true
  def handle_event(
        "handle_game",
        %{"action" => "c", "duration" => d, "max_players" => mp},
        socket
      ) do
    attrs =
      %{
        duration: parse_int(d, 60),
        max_players: parse_int(mp, 2)
      }

    socket.assigns.player_id
    |> Duel.Game.Matchmaker.create_room(attrs)
    |> case do
      {:ok, room_id} ->
        {:noreply,
         socket
         |> put_flash(:info, "Комната создана! Ждем игроков.")
         |> push_navigate(to: ~p"/room/#{room_id}")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Не удалось обработать запрос комнаты.")}
    end
  end

  @impl true
  def handle_event("handle_game", _params, socket) do
    {:noreply, put_flash(socket, :error, "Невозможное действие.")}
  end

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {num, _} ->
        num

      :error ->
        default
    end
  end

  defp parse_int(val, _default) when is_integer(val), do: val
  defp parse_int(_, default), do: default
end
