defmodule AtlasWeb.AclView do
  use AtlasWeb, :view

  def render("acl.json", %{acl: acl, message: message}) do
    %{
      data: %{roles: struct_into_map(acl.roles), resources: struct_into_map(acl.resources)},
      message: message
    }
  end

  def render("role.json", %{role: role, message: message}) do
    %{
      data: struct_into_map(role),
      message: message
    }
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
