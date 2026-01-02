defmodule AtlasWeb.AuthProviderView do
  use AtlasWeb, :view

  def render("auth_providers.json", %{auth_providers: auth_providers, message: message}) do
    %{data: auth_providers, message: message}
  end

  def render("auth_provider.json", %{auth_provider: auth_provider, message: message}) do
    auth_provider = auth_provider |> Map.from_struct() |> Map.drop([:__meta__, :user])

    %{data: auth_provider, message: message}
  end

  def render("error.json", %{error: error}) do
    %{error: error}
  end
end
