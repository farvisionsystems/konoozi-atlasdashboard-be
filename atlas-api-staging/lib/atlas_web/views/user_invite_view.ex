defmodule AtlasWeb.UserInviteView do
  use AtlasWeb, :view

  def render("invite.json", %{invite: invite, message: message}) do
    %{data: struct_into_map(invite), message: message}
  end

  def render("message.json", %{message: message}) do
    %{message: message}
  end

  def render("error.json", %{error: error}) do
    %{error: error}
  end
end
