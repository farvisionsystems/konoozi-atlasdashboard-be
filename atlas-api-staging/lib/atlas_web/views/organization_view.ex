defmodule AtlasWeb.OrganizationView do
  use AtlasWeb, :view

  def render("show.json", %{organization: organization, message: message}) do
    organization =
      organization
      |> Map.from_struct()
      |> Map.drop([:__meta__, :buyers, :notes, :user, :users_organizations])

    %{data: organization, message: message}
  end

  def render("show.json", %{organizations: organizations, message: message}) do
    organizations =
      Enum.map(organizations, fn organization ->
        organization
        |> Map.from_struct()
        |> Map.drop([:__meta__, :buyers, :notes, :user, :users_organizations])
      end)

    %{data: organizations, message: message}
  end

  def render("show.json", %{message: message}), do: %{message: message}

  def render("error.json", %{error: error}), do: %{error: %{message: error}}
end
