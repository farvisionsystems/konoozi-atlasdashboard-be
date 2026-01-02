defmodule AtlasWeb.NoteView do
  use AtlasWeb, :view

  def render("show.json", %{buyer: buyer, message: message}) do
    # user = user |> Map.from_struct() |> Map.drop([:__meta__, :buyers, :notes])
    %{data: buyer, message: message}
  end

  def render("show.json", %{message: message}), do: %{message: message}

  def render("error.json", %{error: error}), do: %{error: %{message: error}}
end
