defmodule AtlasWeb.UserView do
  use AtlasWeb, :view

  def render("user.json", %{user: user, message: message}) do
    user = struct_into_map(user)
    %{data: user, message: message}
  end

  def render("users.json", %{users: users, message: message}) do
    users = struct_into_map(users)

    %{data: users, message: message}
  end

  def render("error.json", %{error: error}) do
    # Transform the error map to extract only the first message for each field
    formatted_error = Enum.into(error, %{}, fn {key, [message | _]} -> {key, message} end)
    %{error: formatted_error}
  end

  def render("message.json", %{message: message}) do
    %{message: message}
  end

  def render("error_account_deletion.json", %{message: message}) do
    %{message: message}
  end
end
