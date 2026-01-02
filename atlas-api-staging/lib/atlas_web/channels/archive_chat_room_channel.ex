defmodule AtlasWeb.ArchiveChatRoomChannel do
  alias Atlas.Threads
  use AtlasWeb, :channel

  @impl true
  def join("archive_chat_room:" <> user_id, _payload, socket) do
    if authorized?(socket, user_id) do
      archived_threads = Threads.get_archived_threads_with_latest_message(user_id)

      {:ok, archived_threads, assign(socket, :archived_threads, archived_threads)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("unarchive_chat", payload, socket) do
    Threads.mark_chat_unarchived(payload["thread_id"], socket.assigns.current_user.id)
    threads = Threads.get_threads_with_latest_message(socket.assigns.current_user.id)

    AtlasWeb.Endpoint.broadcast!(
      "chat_room:#{socket.assigns.current_user.id}",
      "unarchive_chat",
      %{
        "threads" => threads
      }
    )

    archived_threads =
      Threads.get_archived_threads_with_latest_message(socket.assigns.current_user.id)

    AtlasWeb.Endpoint.broadcast!(
      "archive_chat_room:#{socket.assigns.current_user.id}",
      "unarchive_chat",
      %{
        "archived_threads" => archived_threads
      }
    )

    {:reply, {:ok, archived_threads}, socket}
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
