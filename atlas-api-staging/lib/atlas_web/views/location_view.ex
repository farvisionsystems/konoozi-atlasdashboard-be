defmodule AtlasWeb.LocationView do
  use AtlasWeb, :view

  def render("locations.json", %{
        locations: %Scrivener.Page{} = paginated_locations,
        message: message
      }) do
    %{
      data: paginated_locations.entries,
      pagination: %{
        page_number: paginated_locations.page_number,
        page_size: paginated_locations.page_size,
        total_entries: paginated_locations.total_entries,
        total_pages: paginated_locations.total_pages
      },
      message: message
    }
  end

  def render("states.json", %{states: states, message: message}) do
    %{data: states, message: message}
  end

  def render("location.json", %{location: location, message: message}) do
    location = location |> Map.from_struct() |> Map.drop([:__meta__])

    %{data: location, message: message}
  end

  def render("error.json", %{error: error}) do
    %{error: error}
  end
end
