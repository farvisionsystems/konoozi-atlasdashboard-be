defmodule AtlasWeb.ProfileView do
  use AtlasWeb, :view

  def render("profile.json", %{profile: profile, message: message}) do
    %{data: profile, message: message}
  end

  def render("error.json", %{error: error}) do
    # Transform the error map to extract only the first message for each field
    formatted_error = Enum.into(error, %{}, fn {key, [message | _]} -> {key, message} end)
    %{error: formatted_error}
  end
end
