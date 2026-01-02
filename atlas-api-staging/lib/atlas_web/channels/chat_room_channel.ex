defmodule AtlasWeb.ChatRoomChannel do
  alias Atlas.Threads
  use AtlasWeb, :channel

  @impl true
  def join("chat_room:" <> user_id, _payload, socket) do
    threads = Threads.get_threads_with_latest_message(user_id)

    {:ok, threads, assign(socket, :threads, threads)}
  end

  @impl true
  def handle_in("archive_chat", payload, socket) do
    Threads.mark_chat_archived(payload["thread_id"], socket.assigns.current_user.id)
    threads = Threads.get_threads_with_latest_message(socket.assigns.current_user.id)

    archived_threads =
      Threads.get_archived_threads_with_latest_message(socket.assigns.current_user.id)

    AtlasWeb.Endpoint.broadcast!(
      "chat_room:#{socket.assigns.current_user.id}",
      "archive_chat",
      %{
        "threads" => threads
      }
    )

    AtlasWeb.Endpoint.broadcast!(
      "archive_chat_room:#{socket.assigns.current_user.id}",
      "archive_chat",
      %{
        "archived_threads" => archived_threads
      }
    )

    {:reply, {:ok, threads}, socket}
  end

  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(socket, user_id) do
    user_id = if is_binary(user_id), do: String.to_integer(user_id), else: user_id

    if socket.assigns.current_user.id == user_id do
      true
    else
      false
    end
  end
end
