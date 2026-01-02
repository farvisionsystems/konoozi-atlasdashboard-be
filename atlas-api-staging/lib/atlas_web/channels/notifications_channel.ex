defmodule AtlasWeb.NotificationsChannel do
  use AtlasWeb, :channel

  alias Atlas.Accounts.User

  @impl true
  def join("chat_notifications:" <> user_id, payload, socket) do
    if authorized?(socket, user_id) do
      favourites_count = User.get_favourite_buyers_count(user_id)
      {:ok, %{"favourites_count" => favourites_count}, assign(socket, :user_id, user_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  defp authorized?(socket, user_id) do
    user_id = if is_binary(user_id), do: String.to_integer(user_id), else: user_id

    if socket.assigns.current_user.id == user_id do
      true
    else
      false
    end
  end
end
