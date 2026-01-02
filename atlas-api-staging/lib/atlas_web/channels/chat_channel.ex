defmodule AtlasWeb.ChatChannel do
  alias Atlas.{Threads, Message}
  alias Atlas.MobileNotifier
  use AtlasWeb, :channel

  @impl true

  def join("chat:" <> ids, payload, socket) do
    [first_user_id, second_user_id, buyer_id] =
      ids |> String.split(" ") |> Enum.join("") |> String.split(",")

    existing_thread =
      Threads.find_private_conversation_by_users_query(
        first_user_id,
        second_user_id,
        buyer_id
      )
      |> Atlas.Repo.preload(messages: [:parent_message])

    if authorized?(socket, payload) do
      if is_nil(existing_thread) do
        thread =
          Threads.create_or_return_thread(
            first_user_id,
            second_user_id,
            buyer_id
          )

        data = %{
          "thread_id" => thread.id,
          "messages" => thread.messages
        }

        {:ok, data, assign(socket, :thread_id, thread.id)}
      else
        #      call here
        Threads.update_thread_messages_status(existing_thread.id, socket.assigns.current_user.id)

        thread =
          Threads.get_by_id(existing_thread.id)
          |> Atlas.Repo.preload(messages: [:parent_message])

        messages = Message.get_messages(thread.id)

        data = %{
          "thread_id" => thread.id,
          "messages" => messages
        }

        {:ok, data, assign(socket, :thread_id, thread.id)}
      end
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("new_message", payload, socket) do
    first_user_id = payload["first_user_id"]
    second_user_id = payload["second_user_id"]
    buyer_id = payload["buyer_id"]

    existing_thread =
      Threads.find_private_conversation_by_users_query(
        first_user_id,
        second_user_id,
        buyer_id
      )
      |> Atlas.Repo.preload(messages: [:parent_message])

    Threads.maybe_mark_unarchive(
      [first_user_id, second_user_id],
      existing_thread.id
    )

    message = Message.insert_new_message(existing_thread.id, payload)

    broadcast_messages_to_users(
      message,
      first_user_id,
      second_user_id,
      buyer_id,
      existing_thread.id,
      "new_message"
    )

    user_id =
      ([first_user_id, second_user_id] -- [socket.assigns.current_user.id])
      |> List.first()

    #    get FirstUser id
    firstUserID = Atlas.Accounts.get_user(first_user_id)

    single_thread =
      Threads.get_specific_thread_with_latest_message(
        user_id,
        existing_thread.id,
        socket.assigns.current_user.id
      )

    #    get first userName
    first_user_name =
      if firstUserID.profile && firstUserID.profile.first_name,
        do: firstUserID.profile.first_name,
        else: "User"

    # Run the notification in a separate process
    #    IO.inspect(user_id, label: 'fffffffffffffffffffffffffffffff')
    Task.start(fn ->
      MobileNotifier.send_push_notification(
        Integer.to_string(user_id),
        "BuyerBoard",
        message.content,
        first_user_name,
        single_thread,
        second_user_id
      )
    end)

    AtlasWeb.Endpoint.broadcast!(
      "chat_notifications:#{user_id}",
      "new_message",
      %{
        "message" => message
      }
    )

    data = %{
      "thread_id" => existing_thread.id,
      "messages" => message
    }

    {:reply, {:ok, data}, socket}
  end

  @impl true
  def handle_in("delete_message", payload, socket) do
    first_user_id = payload["first_user_id"]
    second_user_id = payload["second_user_id"]
    buyer_id = payload["buyer_id"]

    message_ids =
      Message.get_user_message_ids_via_thread(
        socket.assigns.current_user.id,
        payload["message_ids"]
      )

    messages = Message.delete_messages(message_ids)

    existing_thread =
      Threads.find_private_conversation_by_users_query(
        first_user_id,
        second_user_id,
        buyer_id
      )
      |> Atlas.Repo.preload(messages: [:parent_message])

    broadcast_messages_to_users(
      messages,
      first_user_id,
      second_user_id,
      buyer_id,
      existing_thread.id,
      "delete_message"
    )

    data = %{
      "thread_id" => existing_thread.id,
      "messages" => messages
    }

    {:reply, {:ok, data}, socket}
  end

  @impl true
  def handle_in("edit_message", payload, socket) do
    first_user_id = payload["first_user_id"]
    second_user_id = payload["second_user_id"]
    buyer_id = payload["buyer_id"]
    message_id = payload["message_id"]

    message_belongs_to_user? =
      Message.belongs_to_user?(socket.assigns.current_user.id, message_id)

    if message_belongs_to_user? do
      message = Message.edit_message(message_id, payload["content"])

      existing_thread =
        Threads.find_private_conversation_by_users_query(
          first_user_id,
          second_user_id,
          buyer_id
        )
        |> Atlas.Repo.preload(messages: [:parent_message])

      broadcast_messages_to_users(
        message,
        first_user_id = payload["first_user_id"],
        second_user_id = payload["second_user_id"],
        buyer_id = payload["buyer_id"],
        existing_thread.id,
        "edit_message"
      )

      data = %{
        "thread_id" => existing_thread.id,
        "message" => message
      }

      {:reply, {:ok, data}, socket}
    else
      # {:reply, {status :: atom, response :: map}, Socket.t}
      {:reply, {:error, %{"reason" => "You're not allowed to edit other user's message"}}, socket}
    end
  end

  def broadcast_messages_to_users(
        message,
        first_user_id,
        second_user_id,
        buyer_id,
        thread_id,
        event
      ) do
    AtlasWeb.Endpoint.broadcast!(
      "chat:#{first_user_id}, #{second_user_id}, #{buyer_id}",
      event,
      %{
        "message" => message,
        "thread_id" => thread_id
      }
    )

    AtlasWeb.Endpoint.broadcast!(
      "chat:#{second_user_id}, #{first_user_id}, #{buyer_id}",
      event,
      %{
        "message" => message,
        "thread_id" => thread_id
      }
    )

    AtlasWeb.Endpoint.broadcast!(
      "chat_room:#{first_user_id}",
      event,
      %{
        "threads" => Threads.get_threads_with_latest_message(first_user_id)
      }
    )

    AtlasWeb.Endpoint.broadcast!(
      "chat_room:#{second_user_id}",
      event,
      %{
        "threads" => Threads.get_threads_with_latest_message(second_user_id)
      }
    )

    :ok
  end

  # Add authorization logic here as required.
  defp authorized?(socket, payload) do
    if socket.assigns.current_user.id == payload["first_user_id"] ||
         socket.assigns.current_user.id == payload["second_user_id"] do
      true
    else
      false
    end
  end
end
