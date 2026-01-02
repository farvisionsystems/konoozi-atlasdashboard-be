defmodule AtlasWeb.UserSessionView do
  use AtlasWeb, :view

  def render("user.json", %{user: user, message: message}) do
    user = struct_into_map(user)
    %{data: user, message: message}
  end

  def render("message.json", %{message: message}) do
    %{message: message}
  end

  def render("user.json", %{message: message}), do: %{message: message}

  def render("error.json", %{error: error}), do: %{error: %{message: error}}
end
